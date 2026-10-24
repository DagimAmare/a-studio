// Web push for A Studio (Firebase Cloud Messaging).
// The page asks for permission only when someone taps "Turn on". Pushes
// carry a notification payload, which the Firebase library shows on its
// own; tapping opens the link sent with it (fcmOptions.link).
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyD19QkSbcaBvb3RkkVYQLl30nAQJTVPMjc',
  authDomain: 'astudio-207.firebaseapp.com',
  projectId: 'astudio-207',
  storageBucket: 'astudio-207.firebasestorage.app',
  messagingSenderId: '484644638729',
  appId: '1:484644638729:web:bb1d388db7241bad03a8d8',
});

firebase.messaging();
