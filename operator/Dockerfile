FROM python:3.13.2
ADD ./requirements.txt /
RUN pip install -r /requirements.txt
ADD ./src/ /operator
CMD kopf -vv run /operator/main.py