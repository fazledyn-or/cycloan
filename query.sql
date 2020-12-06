CREATE SEQUENCE OWNER_INCREMENT
INCREMENT BY 1
START WITH 10000
MAXVALUE 50000
NOCYCLE ;


CREATE SEQUENCE CUSTOMER_INCREMENT
INCREMENT BY 1
START WITH 50000
MAXVALUE 90000
NOCYCLE ;


CREATE SEQUENCE CYCLE_INCREMENT
INCREMENT BY 1
START WITH 90000
MAXVALUE 130000
NOCYCLE ;


CREATE SEQUENCE TRIP_INCREMENT
INCREMENT BY 1
START WITH 10000
MAXVALUE 99999
NOCYCLE ;


CREATE SEQUENCE CYCLE_REVIEW_INCREMENT
INCREMENT BY 1
START WITH 10000
MAXVALUE 99999
NOCYCLE ;


CREATE SEQUENCE PEER_REVIEW_INCREMENT
INCREMENT BY 1
START WITH 10000
MAXVALUE 99999
NOCYCLE ;


CREATE SEQUENCE ADMIN_INCREMENT
INCREMENT BY 1
START WITH 1000
MAXVALUE 9999
NOCYCLE ;

-----------------------------OWNS INSERTING TRIGGER--------------------

CREATE OR REPLACE TRIGGER INSERT_OWNS
AFTER INSERT
ON CYCLE
FOR EACH ROW
DECLARE
	OWNER NUMBER;
	CYCLE NUMBER;
BEGIN
	OWNER := :NEW.OWNER_ID;
	CYCLE := :NEW.CYCLE_ID;

	INSERT INTO OWNS(CYCLE_ID, OWNER_ID) VALUES(CYCLE,OWNER);

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/

-----------------------------OWNS TRIGGER TO DELETE--------------------

CREATE OR REPLACE TRIGGER DELETE_OWNS
BEFORE DELETE
ON CYCLE
FOR EACH ROW
DECLARE
	CYCLE NUMBER;
BEGIN
	CYCLE := :OLD.CYCLE_ID;
	DELETE FROM OWNS WHERE CYCLE_ID=CYCLE;
EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/

-------------------------PROCEDURE FOR INSERTING IN CUSTOMER-----------------------

CREATE OR REPLACE PROCEDURE INSERT_CUSTOMER( FNAME IN VARCHAR2, EMAIL IN VARCHAR2, PASS IN VARCHAR2, CONTACT IN VARCHAR2, PPATH IN VARCHAR2, DPATH IN VARCHAR2, DTYPE IN VARCHAR2, TOKCREATED IN VARCHAR2, TOKEXPIRY IN VARCHAR2, TOKEN IN VARCHAR2) IS
	CUS_ID NUMBER;
BEGIN

	INSERT INTO CUSTOMER(CUSTOMER_ID,CUSTOMER_NAME,PASSWORD,CUSTOMER_PHONE,PHOTO_PATH,EMAIL_ADDRESS) VALUES(CUSTOMER_INCREMENT.NEXTVAL,FNAME,PASS,CONTACT,PPATH,EMAIL);

	SELECT CUSTOMER_ID INTO CUS_ID FROM CUSTOMER WHERE EMAIL_ADDRESS=EMAIL;

	INSERT INTO CUSTOMER_EMAIL_VERIFICATION(CUSTOMER_ID, IS_VERIFIED, EMAIL_ADDRESS, TOKEN_CREATED, TOKEN_EXPIRY, TOKEN_VALUE) VALUES(CUS_ID,0,EMAIL,TOKCREATED,TOKEXPIRY,TOKEN);

	INSERT INTO DOCUMENT(CUSTOMER_ID,TYPE_NAME,FILE_PATH) VALUES(CUS_ID,DTYPE,DPATH);

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/

------------------------------------PROCEDURE FOR INSERTING IN OWNER-------------------------

CREATE OR REPLACE PROCEDURE INSERT_OWNER(FNAME IN VARCHAR2, EMAIL IN VARCHAR2, PASS IN VARCHAR2, CONTACT IN VARCHAR2, PPATH IN VARCHAR2, LONGT IN VARCHAR2, LAT IN VARCHAR2, TOKCREATED IN VARCHAR2, TOKEXPIRY IN VARCHAR2, TOKEN IN VARCHAR2) IS
	OWN_ID NUMBER;
BEGIN

	INSERT INTO OWNER(OWNER_ID,OWNER_NAME,PASSWORD,OWNER_PHONE,LONGTITUDE,LATITUDE,PHOTO_PATH,EMAIL_ADDRESS) VALUES(OWNER_INCREMENT.NEXTVAL, FNAME, PASS, CONTACT, LONGT, LAT, PPATH, EMAIL);

	SELECT OWNER_ID INTO OWN_ID FROM OWNER WHERE EMAIL_ADDRESS=EMAIL;

	INSERT INTO OWNER_EMAIL_VERIFICATION(OWNER_ID, IS_VERIFIED, EMAIL_ADDRESS, TOKEN_CREATED, TOKEN_EXPIRY, TOKEN_VALUE) VALUES(OWN_ID, 0, EMAIL, TOKCREATED, TOKEXPIRY, TOKEN);

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/

--------------------------function for owner rating calculation---------------------

CREATE OR REPLACE FUNCTION OWNER_RATING( OWN_ID IN NUMBER )
RETURN NUMBER IS
	OWNER_RATING NUMBER;
BEGIN

	SELECT NVL(AVG(RATING), 0) INTO OWNER_RATING FROM PEER_REVIEW WHERE OWNER_ID=OWN_ID;
	RETURN OWNER_RATING;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/

--------------------------function for CYCLE rating calculation---------------------

CREATE OR REPLACE FUNCTION CYCLE_RATING( CYC_ID IN NUMBER )
RETURN NUMBER IS
	CYCLE_RATING NUMBER;
BEGIN

	SELECT NVL(AVG(RATING), 0) INTO CYCLE_RATING FROM CYCLE_REVIEW WHERE CYCLE_ID=CYC_ID;
	RETURN CYCLE_RATING;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/

-----------------------------------TRIGGER FOR INSERT IN RESERVES-----------------------

CREATE OR REPLACE TRIGGER INSERT_RESERVES
AFTER UPDATE
OF STATUS
ON TRIP_DETAILS
FOR EACH ROW
DECLARE
	NEW_STATUS NUMBER;
	TRIP NUMBER;
	CYC_ID NUMBER;
	CUS_ID NUMBER;
BEGIN

	NEW_STATUS := :NEW.STATUS;
	TRIP := :NEW.TRIP_ID;
	CYC_ID := :NEW.CYCLE_ID;
	CUS_ID := :NEW.CUSTOMER_ID;
	IF NEW_STATUS = 1 THEN
		INSERT INTO RESERVES(TRIP_ID,CYCLE_ID,CUSTOMER_ID) VALUES(TRIP,CYC_ID,CUS_ID);
	END IF;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/

---------------------------------PROCEDURE TO INSERT REVIEW AND UPDATE TRIP (COMPLETE)-----------------------------

CREATE OR REPLACE PROCEDURE REVIEW_INSERT( CYC_RAT IN NUMBER, CYC_COMMENT IN VARCHAR2, OWN_RAT IN NUMBER, OWN_COMMENT IN VARCHAR2, TRP_ID IN NUMBER )IS

	CYC_ID NUMBER;
	CUS_ID NUMBER;
	OWN_ID NUMBER;
BEGIN

	SELECT R.CYCLE_ID, R.CUSTOMER_ID, C.OWNER_ID INTO CYC_ID, CUS_ID, OWN_ID FROM RESERVES R, CYCLE C WHERE R.TRIP_ID = TRP_ID AND R.CYCLE_ID = C.CYCLE_ID;

	INSERT INTO CYCLE_REVIEW(REVIEW_ID,RATING,CUSTOMER_ID,CYCLE_ID,COMMENT_TEXT) VALUES(CYCLE_REVIEW_INCREMENT.NEXTVAL,CYC_RAT,CUS_ID,CYC_ID,CYC_COMMENT);

	INSERT INTO PEER_REVIEW(REVIEW_ID,RATING,CUSTOMER_ID,OWNER_ID,COMMENT_TEXT) VALUES(PEER_REVIEW_INCREMENT.NEXTVAL,OWN_RAT,CUS_ID,OWN_ID,OWN_COMMENT);

	UPDATE TRIP_DETAILS SET STATUS= 4 WHERE TRIP_ID=TRP_ID;


EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
END;
/
------------------------------------------------
-------------------------------------------FUNCTION FOR FARE_CALCULATION----------------------------------------

CREATE OR REPLACE FUNCTION FARE_CALCULATION ( TRP_ID IN NUMBER)
RETURN NUMBER IS
	DAYS NUMBER;
	FARE NUMBER;
	TOTAL_FARE NUMBER;
BEGIN
	SELECT (TD.END_DATE_TIME - TD.START_DATE_TIME), C.FARE_PER_DAY	INTO DAYS, FARE FROM TRIP_DETAILS TD, CYCLE C WHERE TD.TRIP_ID = TRP_ID AND TD.CYCLE_ID = C.CYCLE_ID;

	TOTAL_FARE := DAYS*FARE;
	RETURN TOTAL_FARE;

EXCEPTION
	WHEN NO_DATA_FOUND THEN
		DBMS_OUTPUT.PUT_LINE('NO DATA');
		RETURN -1;
	WHEN OTHERS THEN
		DBMS_OUTPUT.PUT_LINE('DO NOT KNOW');
		RETURN -1;
END;
/
----------------------------------------------------------------------------------