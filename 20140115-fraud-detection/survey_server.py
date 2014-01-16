import conf
import json
import random
from flask import Flask, render_template, request

from boto.sqs.connection import SQSConnection

conn = SQSConnection(conf.AWS_KEY, conf.AWS_SECRET)

q = conn.create_queue('survey_data')

app = Flask(__name__)

surveys = json.load(open(conf.SURVEY_FILE, 'rt'))

surveys_by_id = {s['id']: s for s in surveys}

def get_new_question():
    completed_str = request.form.get('completed')

    possible_surveys = set(surveys_by_id)

    if completed_str:
        for s in completed_str.split(','):
            if s.isdigit():
                possible_surveys.remove(int(s))
    
    if possible_surveys:
        survey_id = random.sample(possible_surveys, 1)[0]
        return surveys_by_id[survey_id]


@app.route('/question>', methods=['GET', 'POST'])
def do_survey(id):
    q = get_new_question()

    if q:
        if 'prompt' in q:
            return render_template('prompt_survey.html',
                                   id=s['id'],
                                   question=s['question'],
                                   n_left=9,
                                   prompt=s['prompt'])
        else:
            # render the prompt template..
            pass
    else:
        # render the "you did it prompts"
        pass

if __name__ == '__main__':
    app.run(debug=True)
