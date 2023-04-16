#!/usr/bin/env bash

curl -i -X POST -d 'email=thomas_man@hotmail.com&name=Tom' \
  http://127.0.0.1:8000/subscriptions