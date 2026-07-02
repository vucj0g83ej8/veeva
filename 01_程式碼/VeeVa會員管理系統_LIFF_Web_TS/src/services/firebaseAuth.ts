import { getAuth } from 'firebase/auth'
import { firebaseApp } from './firebase'

export const firebaseAuth = getAuth(firebaseApp)
firebaseAuth.languageCode = 'zh-TW'
