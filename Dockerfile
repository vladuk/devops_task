FROM python:3.8
WORKDIR /opt/app
RUN pip install pipenv
COPY . /opt/app
RUN pipenv install Pipfile
CMD ["pipenv", "run", "python", "server.py"]
