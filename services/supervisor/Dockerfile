FROM python:3.13.2
ADD ./requirements.txt /
RUN pip install -r /requirements.txt
ADD ./src/ /agent
WORKDIR /agent
CMD ["python3", "main.py"]