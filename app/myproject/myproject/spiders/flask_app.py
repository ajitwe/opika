# flask_app.py
from flask import Flask, request, jsonify
import os
from scrapy.crawler import CrawlerProcess
from myproject.spiders.myspider import QuotesSpider
from scrapy.utils.project import get_project_settings

app = Flask(__name__)

@app.route('/scrape', methods=['POST'])
def scrape():
    data = request.get_json()
    urls = data.get('urls', [])

    if not urls:
        return jsonify({'error': 'No URLs provided'}), 400

    output = []
    process = CrawlerProcess(get_project_settings())

    for url in urls:
        QuotesSpider.start_urls = [url]
        process.crawl(QuotesSpider)
        process.start()  # Blocking call until the spider finishes

        output.append(f'Scraped data for URL: {url}')

    return jsonify({'message': 'Scraping started', 'output': output}), 200

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000)
