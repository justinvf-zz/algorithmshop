python2:
  pkg:
    - installed
    - names:
      - python-dev
      - python

pip:
  pkg:
    - installed
    - name: python-pip
    - require:
      - pkg: python2

virtualenv:
  pip:
    - installed
    - require:
      - pkg: pip

gunicorn:
  pip:
    - installed
    - require:
      - pkg: pip

flask:
  pip:
    - installed
    - require:
      - pkg: pip

boto:
  pip:
    - installed
    - require:
      - pkg: pip
gunicorn -w 4 -b 0.0.0.0:8080 survey_server:APP