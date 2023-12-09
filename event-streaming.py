import pandas as pd
import requests

data = pd.read_csv('data/sample-data.csv')
BASE_URL = 'https://f7e5ce921k.execute-api.us-east-1.amazonaws.com/test/events'

if __name__ == '__main__':
    for i in data.index:
        event = data.loc[i].to_json()
        response = requests.post(BASE_URL, event)
        print(response)
