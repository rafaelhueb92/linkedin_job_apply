import requests
from bs4 import BeautifulSoup

def scrape_weather():
    url = "https://weather.com"
    response = requests.get(url)
    soup = BeautifulSoup(response.text, 'html.parser')
    print(soup.title.string)

scrape_weather()