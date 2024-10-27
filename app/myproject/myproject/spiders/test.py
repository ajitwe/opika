import scrapy
import boto3
import csv
from io import StringIO
from scrapy.exceptions import CloseSpider

class QuotesSpider(scrapy.Spider):
    name = "myspider"

    def __init__(self, url=None, *args, **kwargs):
        super(QuotesSpider, self).__init__(*args, **kwargs)
        self.start_urls = [url] if url else ['http://quotes.toscrape.com']
        self.scraped_data = []  # Store scraped data in memory
        self.s3_client = boto3.client('s3')
        self.bucket_name = 'your-s3-bucket-name'  # Replace with your S3 bucket name

    def parse(self, response):
        for quote in response.css('div.quote'):
            data = {
                'text': quote.css('span.text::text').get(),
                'author': quote.css('small.author::text').get(),
                'tags': quote.css('div.tags a.tag::text').getall(),
            }
            self.scraped_data.append(data)
            yield data  # This still allows Scrapy to output items if needed

    def close(self, reason):
        """Called when the spider finishes, uploads data to S3."""
        if not self.scraped_data:
            raise CloseSpider("No data scraped")
        
        # Convert scraped data to CSV
        csv_buffer = StringIO()
        csv_writer = csv.DictWriter(csv_buffer, fieldnames=['text', 'author', 'tags'])
        csv_writer.writeheader()
        for row in self.scraped_data:
            row['tags'] = ','.join(row['tags'])  # Join tags list into a single string for CSV
            csv_writer.writerow(row)
        
        # Upload the CSV to S3
        self.upload_to_s3(csv_buffer.getvalue())

    def upload_to_s3(self, file_data):
        """Uploads the data to S3."""
        try:
            # Create a unique S3 object name using the spider name and timestamp
            s3_file_name = f"scraped_data/{self.name}-quotes.csv"
            
            # Upload the CSV data to the S3 bucket
            self.s3_client.put_object(
                Bucket=self.bucket_name,
                Key=s3_file_name,
                Body=file_data
            )
            self.logger.info(f"Uploaded data to S3 bucket '{self.bucket_name}' as '{s3_file_name}'")
        except Exception as e:
            self.logger.error(f"Failed to upload data to S3: {str(e)}")
            raise
