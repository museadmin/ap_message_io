MSG_TEMPLATE = {
  "id": "postman_1516347058914",
  "sender": "minitest",
  "action": "SYS_NORMAL_SHUTDOWN",
  "activation": 1,
  "payload": [
    {
      "string": "string"
    },
    {
      "integer": 1
    },
    {
      "array": [
        1,
        2,
        "3"
      ]
    }
  ],
  "ack": 0,
  "date_time": "2018-01-19 07:30:59 +0000"
}
ACCEPT = {'Accept': 'application/json'}
CONTENT = {'Content-Type': 'application/json'}

MSG_ID = 0
MSG_SENDER = 1
MSG_ACTION = 2
MSG_ACTIVATION = 3
MSG_PAYLOAD = 4
MSG_ACK = 5
MSG_DATE_TIME = 6
MSG_DIRECTION = 7
MSG_PROCESSED = 8