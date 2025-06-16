#!/usr/bin/env bash

aws sqs create-queue --queue-name payment_request_created

aws sqs create-queue --queue-name payment_request_authorized

aws sqs list-queues
