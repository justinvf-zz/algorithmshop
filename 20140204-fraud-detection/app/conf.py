from conf_secret import *

assert 'AWS_KEY' in globals()
assert 'AWS_SECRET' in globals()

SURVEY_FILE = 'survey.json'

SQS_QUEUE_NAME = 'fraud_survey_data'
