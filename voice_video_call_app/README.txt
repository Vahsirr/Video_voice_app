Step 1- Run This Command to create a RSA key for generating signed apk and play store release

keytool -genkey -v -keystore  D:\voice_video_call_webrtc_app\voice_video_call_app\upload-keystore.jks -storetype JKS -keyalg RSA -keysize 2048 -validity 10000 -alias upload

Note:-"Change your path according to your directory i.e D:\voice_video_call_webrtc_app\voice_video_call_app\upload-keystore.jks where upload-keystore.jks is the name of key "

Step 2- Add Your Details 

Enter keystore password: 123456
Re-enter new password:  123456
Enter the distinguished name. Provide a single dot (.) to leave a sub-component empty or press ENTER to use the default value in braces.
What is your first and last name?
  [Unknown]:  Anupama Kumari
What is the name of your organizational unit?
  [Unknown]:  Wipenex
What is the name of your organization?
  [Unknown]:  Wipenex
What is the name of your City or Locality?
  [Unknown]:  Bokaro Steel City
What is the name of your State or Province?
  [Unknown]:  Jharkhand
What is the two-letter country code for this unit?
  [Unknown]:  IN
Is CN=Anupama Kumari, OU=Wipenex, O=Wipenex, L=Bokaro Steel City, ST=Jharkhand, C=IN correct?
  [no]:  y

Generating 2,048 bit RSA key pair and self-signed certificate (SHA384withRSA) with a validity of 10,000 days
        for: CN=Anupama Kumari, OU=Wipenex, O=Wipenex, L=Bokaro Steel City, ST=Jharkhand, C=IN
Enter key password for <upload> 123456
        (RETURN if same as keystore password):
Re-enter new password: 123456

Step 3 - Make a file called "key.properties" inside the android folder and add 

storePassword=123456
keyPassword=123456
keyAlias=upload
storeFile=D:/voice_video_call_webrtc_app/voice_video_call_app/upload-keystore.jks (change according to your keystroke location)

Step 4 - Add the following code before the android function inside android/app/build.gradle if not added

def keystoreProperties = new Properties()
   def keystorePropertiesFile = rootProject.file('key.properties')
   if (keystorePropertiesFile.exists()) {
       keystoreProperties.load(new FileInputStream(keystorePropertiesFile))
   }

Step 5 - Replace the code of buildTypes function inside android/app/build.gradle if not done

signingConfigs {
       release {
           keyAlias keystoreProperties['keyAlias']
           keyPassword keystoreProperties['keyPassword']
           storeFile keystoreProperties['storeFile'] ? file(keystoreProperties['storeFile']) : null
           storePassword keystoreProperties['storePassword']
       }
   }
   buildTypes {
       release {
           signingConfig signingConfigs.release
       }
   }

Step 6 - Run the following command in the terminal for generating apk 

    "flutter build apk"

Step 7 - You will see your apk inside

    "build\app\outputs\flutter-apk\app-release.apk"

And this is the SHA-1 certificate fingerprint -> CD:77:C6:7A:1C:CA:4A:1A:40:22:3D:2F:74:9D:6E:34:E1:4B:D6:3F    