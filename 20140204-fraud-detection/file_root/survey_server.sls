git:
  pkg:
    - installed

https://github.com/justinvf/algorithmshop.git:
  git.latest:
    - target: /var/survey_server

/var/survey_server/20140115-fraud-detection/app/conf_secret.py:
  file.managed:
    - source: salt://survey/conf_secret.py
    - source: salt://conf_secret.py
