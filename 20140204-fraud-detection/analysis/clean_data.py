import time
import json
import os
import sys
from http import client
import random

SALT = str(random.randint(0,12030120321))

conn = client.HTTPConnection('freegeoip.net')

def ip_lookup(ip_addr):
    global conn
    conn.request('GET', '/json/{}'.format(ip_addr))
    time.sleep(.05)
    r = None
    for i in range(3):
        try:
            r = conn.getresponse()
            break
        except:
            time.sleep(.3)

    if not r or r.status != 200:
        conn = client.HTTPConnection('freegeoip.net')
        print('Problem: {}'.format(ip_addr))
        if r.status == 404:
            return {'location': 'Unknown'}
        else:
            return {}
    return json.loads(str(r.read(), 'utf-8'))


path_map = {
    '/question?u=mtnreq5': 'Mechanical Turk 5 Cents',
    '/question?u=fbk': 'Facebook',
    '/question?u=mtnreq2': 'Mechanical Turk 2 Cents',
    '/question?u=tm59005': 'Mechanical Turk High Skill Request',
    '/question?u=tiff': 'Tiffany',
    '/question?u=testing': None,
    '/question?u=test': None,
    '/question?u=aw02': 'AdWords, asking for 2 cents.',
    '/question?u=mtnreqfast': 'Turk, asking for Fast',
    '/question?u=ttr': 'Twitter',
    '/question?': None}


def process_file(filename, ip_cache):

    all_data = json.load(open(filename))

    print('All data: ', len(all_data))

    submitted_questions = [x for x in all_data if x.get('form')]

    cleaned_data = []

    for s in submitted_questions:
        f = s.pop('form')
        s['srv_time'] = float(f.pop('srv_time'))
        s['question_id'] = int(f.pop('question_id'))
        s['survey_order_id'] = f.pop('survey_order_id')
        s['user_id'] = f.pop('user_id')
        if 'answer' in f:
            s['answer'] = f.pop('answer')
        else:
            s['answer'] = ' '.join('{}:{}'.format(k,v) for (k,v) in f.items())

        # not really useful..
        s.pop('referrer')

        # Get the ip data, and remove ip address.
        ip_addr = s.pop('ip')

        s['ip_hash'] = hash(SALT + ip_addr)

        if ip_addr not in ip_cache:
            ip_data = ip_lookup(ip_addr)
            # Only cache real results..
            if ip_data:
                ip_cache[ip_addr] = ip_data

        ip_data = ip_cache.get(ip_addr, {})
        for k in ('city', 'country_name', 'latitude', 'longitude', 'region_name'):
            s[k] = ip_data.get(k)

        try:
            path = s.pop('path')
            s['type'] = path_map[path]
        except:
            print('No info for path ', path)

        if s['type']:
            cleaned_data.append(s)

    return cleaned_data

def dedupe(collection, key_function):
    seen = set()
    to_return = []
    for i in collection:
        k = key_function(i)
        if k not in seen:
            seen.add(k)
            to_return.append(i)
    return to_return


if __name__ == '__main__':
    all_responses = []
    if os.path.exists('ip_cache.json'):
        ip_cache = json.load(open('ip_cache.json', 'rt'))
    else:
        ip_cache = {}

    try:
        for filename in sys.argv[1:]:
            print('processing ', filename)
            all_responses.extend(process_file(filename, ip_cache))
    finally:
        with open('ip_cache.json', 'wt') as f:
            json.dump(ip_cache, f)

    print('Num responses: ', len(all_responses))

    # Maybe data was downloaded multiple times or something...
    deduped = dedupe(all_responses, lambda x: (x['srv_time'], x['user_id']))

    print('Num after deduping: ', len(deduped))

    with open('cleaned_data.json', 'wt') as f:
        # I want one per line, so I can read in a text editor
        # but it's not super long
        f.write('[\n  ')
        f.write(',\n  '.join(json.dumps(d) for d in deduped))
        f.write('\n]')
