'''
Pull data down from SQS where we have been keeping it:

python data_pull.py ../analysis/sqs_data/pull_20140131.json
'''

import conf
import json
from boto.sqs.connection import SQSConnection, Message
import os
import sys
import time

SQS_CONN = SQSConnection(conf.AWS_KEY, conf.AWS_SECRET)
SQS_QUEUE = SQS_CONN.create_queue(conf.SQS_QUEUE_NAME)

if __name__ == '__main__':
    output_file = sys.argv[1]
    assert(not os.path.exists(output_file))
    message_bodys = []
    message_objects = []
    some_messages = SQS_QUEUE.get_messages(10)
    while some_messages:
        message_bodys.extend(json.loads(m.get_body())
                             for m in some_messages)
        message_objects.extend(some_messages)
        some_messages = SQS_QUEUE.get_messages(10)
        print '.',

    print('Got ', len(message_bodys), ' messages')

    with open(output_file, 'wt') as f:
        json.dump(message_bodys, f)

    for m in message_objects:
        m.delete()
