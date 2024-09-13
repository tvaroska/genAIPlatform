FROM python:3.12

WORKDIR /proxy

ADD requirements.txt .
RUN pip install -r requirements.txt

ADD config.yaml .

EXPOSE 4000

CMD ["litellm", "--config", "config.yaml"]