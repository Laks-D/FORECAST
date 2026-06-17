/* eslint-disable no-undef */

importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'REDACTED',
  authDomain: 'generalapp-dev-3de9b.firebaseapp.com',
  projectId: 'generalapp-dev-3de9b',
  storageBucket: 'generalapp-dev-3de9b.firebasestorage.app',
  messagingSenderId: '1073450813962',
  appId: '1:1073450813962:web:5a66fe7b2be7a725736df3',
  measurementId: 'G-LZHXCT31FY',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload?.notification?.title || 'Notification';
  const options = {
    body: payload?.notification?.body,
    icon: '/icons/Icon-192.png',
    data: payload?.data,
  };

  self.registration.showNotification(title, options);
});
