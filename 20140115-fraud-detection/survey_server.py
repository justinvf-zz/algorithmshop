import conf
from time import time
import json
import random
from boto.sqs.connection import SQSConnection, Message
from flask import Flask, render_template, request

VERSION = "0.1"

APP = Flask(__name__)

SQS_CONN = SQSConnection(conf.AWS_KEY, conf.AWS_SECRET)
SQS_QUEUE = SQS_CONN.create_queue(conf.SQS_QUEUE_NAME)


SURVEY = json.load(open(conf.SURVEY_FILE, 'rt'))

QUESTIONS_BY_ID = {q['id']: q for q in SURVEY['questions']}
ORDERS_BY_ID = {o['id']: o for o in SURVEY['question_orders']}


def build_sampling_map():
    m = {}
    i = 0
    for o in SURVEY['question_orders']:
        for j in range(o['frequency']):
            m[i + j] = o['id']
        i += o['frequency']
    return m


SAMPLING_MAP = build_sampling_map()


DONE = object()
def get_next_question_id(order_id):
    last_completed_str = request.form.get('question_id')
    if not last_completed_str:
        return ORDERS_BY_ID[order_id]['order'][0]
    else:
        # Ideally there would be error handling here.
        # But this is all a hack.
        last_completed = int(last_completed_str)
        question_ordering = ORDERS_BY_ID[order_id]['order']
        index = question_ordering.index(last_completed)
        if index == len(question_ordering) -1:
            return DONE
        else:
            return question_ordering[index + 1]


def get_random_survey():
    """Returns a random survey, weighted by the 'frequency' value."""
    return random.sample(SAMPLING_MAP.values(), 1)[0]


def log_stuff():
    to_log = {}
    to_log['version'] = VERSION
    to_log['form'] = dict(request.form.items())
    to_log['submit_time'] = time()
    to_log['ip'] = request.remote_addr
    to_log['referrer'] = request.referrer
    to_log['path'] = request.full_path
    print(to_log)
    m = Message()
    m.set_body(json.dumps(to_log))
    SQS_QUEUE.write(m)


@APP.route('/question', methods=['GET', 'POST'])
def do_survey():
    # Save our precious data to SQS!
    log_stuff()

    order_id = request.form.get('survey_order_id', get_random_survey())
    next_question_id = get_next_question_id(order_id)

    user_id = request.form.get('user_id') or random.randint(0,100000000000)

    if next_question_id == DONE:
        return render_template('all_done.html',
                               code=ORDERS_BY_ID[order_id]['done_token'])
    else:
        question = QUESTIONS_BY_ID[next_question_id]
        if 'prompt' in question:
            return render_template('prompt_survey.html',
                                   time=time(),
                                   user_id=user_id,
                                   question=question,
                                   order_id=order_id)
        else:
            return render_template('multi_survey.html',
                                   time=time(),
                                   user_id=user_id,
                                   question=question,
                                   order_id=order_id)


if __name__ == '__main__':
    APP.run(debug=True)
