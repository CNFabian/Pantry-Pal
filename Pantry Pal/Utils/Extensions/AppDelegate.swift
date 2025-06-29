import FirebaseInAppMessaging
import FirebaseFirestore
import Firebase


func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

    FirebaseApp.configure()
    
    InAppMessaging.inAppMessaging().automaticDataCollectionEnabled = false
    InAppMessaging.inAppMessaging().messageDisplaySuppressed = true
    print("✅ Firebase configured with In-App Messaging disabled")
    
    // Rest of your existing code...
    return true
}
