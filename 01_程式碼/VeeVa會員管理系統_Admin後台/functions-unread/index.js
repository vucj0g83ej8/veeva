import { initializeApp } from 'firebase-admin/app';
import { FieldValue, getFirestore } from 'firebase-admin/firestore';
import { onDocumentCreated } from 'firebase-functions/v2/firestore';

initializeApp();

const db = getFirestore();

export const countUnreadLineConversationMessage = onDocumentCreated(
  {
    document: 'lineConversations/{lineUserId}/messages/{messageId}',
    region: 'asia-east1',
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (event) => {
    const messageReference = event.data?.ref;
    const conversationReference = messageReference?.parent.parent;
    if (!messageReference || !conversationReference) return;

    await db.runTransaction(async (transaction) => {
      const messageSnapshot = await transaction.get(messageReference);
      const message = messageSnapshot.data();
      if (!messageSnapshot.exists || message?.direction !== 'incoming') return;
      if (message.unreadCounted === true) return;

      transaction.update(messageReference, {
        unreadCounted: true,
        unreadCountedAt: FieldValue.serverTimestamp(),
      });
      transaction.set(
        conversationReference,
        {
          unreadCount: FieldValue.increment(1),
          lastIncomingMessageAt:
            message.sentAt ?? FieldValue.serverTimestamp(),
          updatedAt: FieldValue.serverTimestamp(),
        },
        { merge: true },
      );
    });
  },
);
