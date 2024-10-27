import pytest
from scrapy.crawler import CrawlerProcess
from scrapy.utils.project import get_project_settings
from scrapy import signals
from myproject.myproject.spiders.myspider import QuotesSpider

@pytest.fixture
def crawler_process():
    return CrawlerProcess(get_project_settings())

def test_spider(crawler_process):
    scraped_items = []

    # Define a signal to capture items scraped
    def collect_item(item, response, spider):
        scraped_items.append(item)

    # Get a Crawler object and connect the signal
    crawler = crawler_process.create_crawler(QuotesSpider)
    crawler.signals.connect(collect_item, signal=signals.item_scraped)

    # Run the spider and block until it finishes
    crawler_process.crawl(crawler)
    crawler_process.start()  # This blocks the test until the spider finishes

    # Now you can make assertions on `scraped_items`
    assert len(scraped_items) > 0  # Ensure that items were scraped
