import mysql.connector
import time

cnx = mysql.connector.connect(
    user='root',
    password='SecretPassword',
    host='mysql',
    database='employees'
)

i = 1
while True:
    print(i)
    time.sleep(1)
    i += 1