A simple on the surface but mildly complicated **Flutter** app using a **machine learning** model. The model runs on a **Python** server and is used to detect palm oil plantations in images uploaded by the user from their gallery. It interacts with the mobile app via **Firebase** through API requests after proceeding through a **Square payment gateway**.

Built in less than a week over a normal work week with no previous experience in Flutter/Firebase/Square.


Login, basic UI and payment system started from forked repo: https://github.com/efortuna/shrine_with_square

Firebase communication and python server inspired by this repo: https://github.com/ZbigniewTomanek/image_classification_with_flutter

# Setup and usage
Run the python flask app found in **FlutterMLApp/python** with
```
flask run --host=0.0.0.0
```
This puts the machine learning model in service to be requested by the Android app. This is not for serving a web app.

In **lib/service.dart**, a URL variable at the top of the file is set by default. This is the URL necessary for the app running on an Android emulator to find the Python server, which should be running on your local machine. **You may need to change this depending on where you run the Python server**

Once this is running, go ahead and launch the app on an Android emulator (if you need to set up an Android emulator or Flutter, follow their installation tutorial: https://flutter.dev/docs/get-started/install).

Select an image and make a payment (no payments are actually made, this is a test app).
The default card on Sqaure to use is **4111 1111 1111 1111**
