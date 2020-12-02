from django.shortcuts import render, redirect
from django.db import connection
from django.views import View
from django.contrib import messages

from .utils import save_customer_doc, save_customer_photo
from core.utils import create_auth_token, send_verification_email
from cycloan.settings import SECRET_KEY

from datetime import datetime, timedelta
import jwt, threading

## decorators
from core.utils import verify_auth_token, check_customer


class CustomerLoginView(View):

    def get(self, request):
        if request.session.get('auth_token'):
            return redirect('owner-dashboard-view')
        return redirect('login-view')

    def post(self, request):
        customer_email = request.POST.get('customer-email')
        customer_pass = request.POST.get('customer-password')

        cursor = connection.cursor()
        sql = "SELECT PASSWORD, CUSTOMER_ID FROM CUSTOMER WHERE EMAIL_ADDRESS=%s"
        cursor.execute(sql, [customer_email])
        result = cursor.fetchall()
        cursor.close()

        try:
            fetched_pass = result[0][0]
            if fetched_pass == customer_pass:
                customer_id = result[0][1]

                cursor = connection.cursor()
                sql = "SELECT IS_VERIFIED FROM CUSTOMER_EMAIL_VERIFICATION WHERE EMAIL_ADDRESS=%s"
                cursor.execute(sql, [customer_email])
                verify = cursor.fetchall()
                cursor.close()
                v = int(verify[0][0])

                if v == 0:
                    messages.error(request, 'Email has not been verified yet. Please check your email and verify.')
                    return redirect('login-view')
                else:
                    request.session['customer_id'] = customer_id
                    request.session['auth_token'] = create_auth_token(customer_id)
                    request.session['user_type'] = 'customer'
                    return redirect('customer-dashboard-view')
            else:
                messages.error(request, 'Password mismatched. Enter correctly!')
                return redirect('login-view')
        except:
            messages.error(request, 'Your email was not found in database. Enter correctly!')
            return redirect('login-view')


class CustomerLogoutView(View):

    @verify_auth_token
    @check_customer
    def get(self, request):
        request.session.pop('customer_id', None)
        request.session.pop('user_type', None)
        request.session.pop('auth_token', None)
        messages.info(request, 'You are logged out.')
        return redirect('login-view')


class CustomerRegisterView(View):

    def get(self, request):
        if request.session.get('auth_token'):
            return redirect('owner-dashboard-view')
        return render(request, 'customer_register.html')

    def post(self, request):

        photo = request.FILES.get('photo')
        email = request.POST.get('email')
        password = request.POST.get('password')
        password_confirm = request.POST.get('password_confirm')
        fullname = request.POST.get('fullname')
        contact = request.POST.get('contact')
        doctype = request.POST.get('doctype')
        document = request.FILES.get('document')

        if password != password_confirm:
            messages.warning(request, 'Passwords do not match. Check again')
            return redirect('customer-register-view')
        else:
            cursor = connection.cursor()
            sql = "SELECT COUNT(*) FROM CUSTOMER WHERE EMAIL_ADDRESS=%s"
            cursor.execute(sql, [email])
            result = cursor.fetchall()
            cursor.close()
            count = int(result[0][0])

            if count == 0:
                cursor = connection.cursor()
                sql = "SELECT COUNT(*) FROM CUSTOMER"
                cursor.execute(sql)
                result = cursor.fetchall()
                cursor.close()
                count = int(result[0][0])
                customer_count = 50001 + count
                photo_path = save_customer_photo(photo, customer_count, contact)
                doc_path = save_customer_doc(document, customer_count, contact)

                cursor = connection.cursor()
                sql = "INSERT INTO CUSTOMER(CUSTOMER_ID,CUSTOMER_NAME,PASSWORD,CUSTOMER_PHONE,PHOTO_PATH,EMAIL_ADDRESS) VALUES(CUSTOMER_INCREMENT.NEXTVAL, %s, %s, %s, %s, %s)"
                cursor.execute(sql, [fullname, password, contact, photo_path, email])
                connection.commit()
                cursor.close()

                cursor = connection.cursor()
                sql = "SELECT CUSTOMER_ID FROM CUSTOMER WHERE EMAIL_ADDRESS=%s"
                cursor.execute(sql, [email])
                result = cursor.fetchall()
                cursor.close()
                customer_id = result[0][0]

                cursor = connection.cursor()
                sql = "INSERT INTO DOCUMENT(CUSTOMER_ID,TYPE_NAME,FILE_PATH) VALUES(%s, %s, %s)"
                cursor.execute(sql, [customer_id, doctype, doc_path])
                connection.commit()
                cursor.close()

                """
                TOKEN MAKING
                """
                token_created = datetime.now()
                token_expiry = token_created + timedelta(days=1)
                
                verification_token = jwt.encode(
                    {
                        'user_type': 'customer',
                        'user_email': customer_email,
                        'token_expiry': str(token_expiry)
                    }, SECRET_KEY, algorithm='HS256'
                ).decode('utf-8')

                cursor = connection.cursor()
                sql = "INSERT INTO CUSTOMER_EMAIL_VERIFICATION(CUSTOMER_ID, IS_VERIFIED, EMAIL_ADDRESS, TOKEN_CREATED, TOKEN_EXPIRY, TOKEN_VALUE) VALUES(%s, %s, %s, %s, %s, %s)"
                cursor.execute(sql, [customer_id, 0, email, token_created, token_expiry, verification_token])
                connection.commit()
                cursor.close()

                print("#################################################")
                print("VER TOKEN: ", verification_token)
                print("#################################################")

                email_thread = threading.Thread(target=send_verification_email, args=(email, fullname, 'customer', verification_token))
                email_thread.start()

                messages.success(request, 'Account create successful. Now you can login.')
                return redirect('login-view')

            else:
                messages.warning(request, 'Account exists with similar email. Please provide different email')
                return redirect('customer-register-view')


class CustomerDashboardView(View):

    @verify_auth_token
    @check_customer
    def get(self, request):
        customer_id = request.session.get('customer_id')
        cursor = connection.cursor()
        sql = "SELECT CUSTOMER_NAME FROM CUSTOMER WHERE CUSTOMER_ID=%s"
        cursor.execute(sql, [customer_id])
        result = cursor.fetchall()
        cursor.close()
        customer_name = result[0][0]
        print(customer_name)
        context = {'customer_name': customer_name}
        return render(request, 'customer_dashboard.html', context)


class CustomerProfileView(View):

    @verify_auth_token
    @check_customer
    def get(self, request):
        print(request.session['auth_token'])

        cursor = connection.cursor()

        customer_id = request.session.get('customer_id')
        sql = "SELECT * FROM CUSTOMER WHERE CUSTOMER_ID=%s"
        cursor.execute(sql, [customer_id])
        result = cursor.fetchall()
        cursor.close()

        customer_id = result[0][0]
        customer_name = result[0][1]
        customer_photo = result[0][3]
        customer_phone = result[0][4]
        customer_email = result[0][5]

        context = {
            'customer_id': customer_id,
            'customer_name': customer_name,
            'customer_photo': customer_photo,
            'customer_phone': customer_phone,
            'customer_email': customer_email
        }

        return render(request, 'customer_profile.html', context)

    @verify_auth_token
    @check_customer
    def post(self, request):

        cursor = connection.cursor()
        customer_id = request.session.get('customer_id')
        sql = "SELECT PASSWORD FROM CUSTOMER WHERE CUSTOMER_ID=%s"
        cursor.execute(sql, [customer_id])
        result = cursor.fetchall()
        cursor.close()        

        #####################   WORK LEFT   ####################
        ########################################################

        old_password = request.POST.get('old_password')
        new_password = request.POST.get('new_password')
        new_password_confirm = request.POST.get('new_password_confirm')

        customer_new_phone = request.POST.get('customer_new_phone')
        customer_new_photo = request.FILES.get('customer_new_photo')

        old_password_from_db = result[0][0]

        if old_password == "" and new_password == "" and new_password_confirm == "":
            
            if len(request.FILES) != 0:
                cursor = connection.cursor()
                sql = "SELECT CUSTOMER_PHONE FROM CUSTOMER WHERE CUSTOMER_ID=%s"
                cursor.execute(sql, [customer_id])
                result = cursor.fetchall()
                cursor.close()
                contact = result[0][0]

                new_photo_path = save_customer_photo(customer_new_photo, customer_id, contact)
                cursor = connection.cursor()
                sql = "UPDATE CUSTOMER SET PHOTO_PATH = %s WHERE CUSTOMER_ID = %s"
                cursor.execute(sql, [new_photo_path, customer_id])
                connection.commit()
                cursor.close()
            
            cursor = connection.cursor()
            sql = "UPDATE CUSTOMER SET CUSTOMER_PHONE = %s WHERE CUSTOMER_ID = %s"
            cursor.execute(sql, [customer_new_phone, customer_id])
            connection.commit()
            cursor.close()
            
            messages.success(request, 'Profile updated !')

        else:
            if new_password == new_password_confirm:
                
                if old_password == old_password_from_db:        
                    cursor = connection.cursor()
                    sql = "UPDATE CUSTOMER SET PASSWORD = %s WHERE CUSTOMER_ID = %s"
                    cursor.execute(sql, [new_password, customer_id])
                    connection.commit()
                    cursor.close()
                    messages.success(request, 'Password updated !')
            
                else:
                    messages.error('Enter current password correctly!')

            else:
                messages.error('The new passwords do not match! Type carefully.')
    
        return redirect('customer-profile-view')
