import { initializeApp } from 'firebase/app'
import { getFirestore } from 'firebase/firestore'
import { getStorage } from 'firebase/storage'

export const firebaseConfig = {
  apiKey:
    import.meta.env.VITE_FIREBASE_API_KEY ??
    'AIzaSyAhPSWe0Vx8DTOC7gtp5ZJO1jfBnE3Y9oU',
  authDomain:
    import.meta.env.VITE_FIREBASE_AUTH_DOMAIN ?? 'veeva-8d30c.firebaseapp.com',
  projectId: import.meta.env.VITE_FIREBASE_PROJECT_ID ?? 'veeva-8d30c',
  storageBucket:
    import.meta.env.VITE_FIREBASE_STORAGE_BUCKET ??
    'veeva-8d30c.firebasestorage.app',
  messagingSenderId:
    import.meta.env.VITE_FIREBASE_MESSAGING_SENDER_ID ?? '448360837259',
  appId:
    import.meta.env.VITE_FIREBASE_APP_ID ??
    '1:448360837259:web:d632a699cce1259b7ee48e',
}

export const firebaseApp = initializeApp(firebaseConfig)
export const firestore = getFirestore(firebaseApp)
export const storage = getStorage(firebaseApp)

