#!/usr/bin/env python3
import argparse
import json
import os
import re
import requests
import sys


TOKEN = os.environ['TOKEN']


def convert_links(links):
    mapping = {}
    for link in links.split(', '):
        _url, label = link.split('; ')
        label = re.search('rel="(.*)"', label).group(1)
        _url = _url[1:-1]
        assert label not in mapping
        mapping[label] = _url
    return mapping


def get(url):
    headers = {'Authorization': f'Token {TOKEN}'}
    print(f'Getting {url} ...', file=sys.stderr)
    return requests.get(url, headers=headers)


def fetch_zone(zone):
    url = f'https://desec.io/api/v1/domains/{zone}/rrsets/'
    response = get(url)

    if response.status_code == 200:
        return response.json()

    if response.status_code == 400 and 'Link' in response.headers:
        print(f'Response: {response.status_code} {response.json()["detail"]}', file=sys.stderr)
        rrsets = []
        links = convert_links(response.headers['Link'])
        url = links['first']
        while url is not None:
            response = get(url)
            rrsets += response.json()
            links = convert_links(response.headers['Link'])
            url = links.get('next')
        return rrsets

    raise RuntimeError


if __name__ == '__main__':
    description='Fetch zone contents from deSEC. Access token is expected in $TOKEN environment variable.'
    parser = argparse.ArgumentParser(description=description)
    parser.add_argument('zone', type=str, help='Zone to fetch')

    args = parser.parse_args()
    zone = args.zone
    rrsets = fetch_zone(zone)
    print(json.dumps(rrsets))

