from django.db import connection
from django.shortcuts import render
from django.views import View


class CustomerPublicView(View):

    def get(self, request, customer_id):

        cursor = connection.cursor()
        sql = "SELECT CUSTOMER_NAME,PHOTO_PATH,CUSTOMER_PHONE,EMAIL_ADDRESS FROM CUSTOMER WHERE CUSTOMER_ID=%s"
        cursor.execute(sql, [customer_id])
        result = cursor.fetchall()
        cursor.close()
        name = result[0][0]
        photo_path = result[0][1]
        phone = result[0][2]
        email = result[0][3]

        cursor = connection.cursor()
        sql = "SELECT TYPE_NAME,FILE_NAME,DESCRIPTION FROM DOCUMENT WHERE CUSTOMER_ID=%s"
        cursor.execute(sql, [customer_id])
        info = cursor.fetchall()
        cursor.close()
        doctype = info[0][0]
        doc_path = info[0][1]
        description = info[0][2]


class OwnerPublicView(View):

    def get(self, request, owner_id):
        
        cursor = connection.cursor()
        sql = "SELECT OWNER_NAME,PHOTO_PATH,OWNER_PHONE,LOCATION,EMAIL_ADDRESS,RATING FROM OWNER WHERE OWNER_ID=%s"
        cursor.execute(sql, [owner_id])
        result = cursor.fetchall()
        cursor.close()
        name = result[0][0]
        photo_path = result[0][1]
        phone = result[0][2]
        location = result[0][3]
        email = result[0][4]
        rating = result[0][5]

        cursor = connection.cursor()
        sql = "SELECT PHOTO,MODEL,RATING FROM CYCLE WHERE OWNER_ID = %s"
        cursor.execute(sql, owner_id)
        cycle = cursor.fetchall()
        cursor.close()
