
// Config
const PROJECT_ID = 'rotty-music';
const API_KEY = 'AIzaSyDkD9uaVanSvrsAg_Myg7mYKW0GSjB0t7w';
const BASE_URL = `https://firestore.googleapis.com/v1/projects/${PROJECT_ID}/databases/(default)/documents`;
const AUTH_BASE = 'https://identitytoolkit.googleapis.com/v1/accounts';

// Helpers to encode/decode Firestore REST format
function encodeValue(val: any): any {
  if (val === null || val === undefined) return { nullValue: null };
  if (typeof val === 'string') return { stringValue: val };
  if (typeof val === 'boolean') return { booleanValue: val };
  if (typeof val === 'number') return { doubleValue: val };
  if (Array.isArray(val)) {
    return {
      arrayValue: {
        values: val.map(item => encodeValue(item))
      }
    };
  }
  if (typeof val === 'object') {
    const fields: Record<string, any> = {};
    Object.entries(val).forEach(([k, v]) => {
      fields[k] = encodeValue(v);
    });
    return {
      mapValue: {
        fields
      }
    };
  }
  return { stringValue: String(val) };
}

function decodeValue(field: any): any {
  if (!field) return null;
  if ('nullValue' in field) return null;
  if ('stringValue' in field) return field.stringValue;
  if ('booleanValue' in field) return field.booleanValue;
  if ('doubleValue' in field) return field.doubleValue;
  if ('integerValue' in field) return parseInt(field.integerValue, 10);
  if ('arrayValue' in field) {
    const values = field.arrayValue.values || [];
    return values.map((item: any) => decodeValue(item));
  }
  if ('mapValue' in field) {
    const fields = field.mapValue.fields || {};
    const result: Record<string, any> = {};
    Object.entries(fields).forEach(([k, v]) => {
      result[k] = decodeValue(v);
    });
    return result;
  }
  return null;
}

export const FirestoreRest = {
  async getDoc(path: string): Promise<Record<string, any> | null> {
    try {
      const response = await fetch(`${BASE_URL}/${path}?key=${API_KEY}`);
      if (response.status === 200) {
        const body = await response.json();
        const fields = body.fields || {};
        const result: Record<string, any> = {};
        Object.entries(fields).forEach(([k, v]) => {
          result[k] = decodeValue(v);
        });
        return result;
      }
      return null;
    } catch (e) {
      console.error('FirestoreRest getDoc error:', e);
      return null;
    }
  },

  async setDoc(path: string, data: Record<string, any>, merge = false): Promise<void> {
    try {
      const fields: Record<string, any> = {};
      Object.entries(data).forEach(([k, v]) => {
        fields[k] = encodeValue(v);
      });
      
      let url = `${BASE_URL}/${path}?key=${API_KEY}`;
      if (merge) {
        Object.keys(data).forEach(k => {
          url += `&updateMask.fieldPaths=${k}`;
        });
      }

      await fetch(url, {
        method: 'PATCH',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields })
      });
    } catch (e) {
      console.error('FirestoreRest setDoc error:', e);
    }
  },

  async deleteDoc(path: string): Promise<void> {
    try {
      await fetch(`${BASE_URL}/${path}?key=${API_KEY}`, {
        method: 'DELETE'
      });
    } catch (e) {
      console.error('FirestoreRest deleteDoc error:', e);
    }
  },

  async listDocs(collectionPath: string): Promise<Record<string, any>[]> {
    try {
      const response = await fetch(`${BASE_URL}/${collectionPath}?key=${API_KEY}`);
      if (response.status === 200) {
        const body = await response.json();
        const documents = body.documents || [];
        return documents.map((doc: any) => {
          const id = doc.name.split('/').pop() || '';
          const fields = doc.fields || {};
          const map: Record<string, any> = { id };
          Object.entries(fields).forEach(([k, v]) => {
            map[k] = decodeValue(v);
          });
          return map;
        });
      }
      return [];
    } catch (e) {
      console.error('FirestoreRest listDocs error:', e);
      return [];
    }
  },

  async addDoc(collectionPath: string, data: Record<string, any>): Promise<void> {
    try {
      const fields: Record<string, any> = {};
      Object.entries(data).forEach(([k, v]) => {
        fields[k] = encodeValue(v);
      });

      await fetch(`${BASE_URL}/${collectionPath}?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ fields })
      });
    } catch (e) {
      console.error('FirestoreRest addDoc error:', e);
    }
  }
};

export const FirebaseAuthRest = {
  async signIn(email: string, password: string): Promise<{ localId: string; email: string; idToken: string } | null> {
    try {
      const response = await fetch(`${AUTH_BASE}:signInWithPassword?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true })
      });
      
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error?.message || 'Failed to sign in');
      }

      return {
        localId: data.localId,
        email: data.email,
        idToken: data.idToken
      };
    } catch (e: any) {
      console.error('FirebaseAuthRest signIn error:', e);
      throw e;
    }
  },

  async signUp(email: string, password: string): Promise<{ localId: string; email: string; idToken: string } | null> {
    try {
      const response = await fetch(`${AUTH_BASE}:signUp?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ email, password, returnSecureToken: true })
      });
      
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error?.message || 'Failed to register');
      }

      return {
        localId: data.localId,
        email: data.email,
        idToken: data.idToken
      };
    } catch (e: any) {
      console.error('FirebaseAuthRest signUp error:', e);
      throw e;
    }
  },

  async sendPasswordReset(email: string): Promise<void> {
    try {
      const response = await fetch(`${AUTH_BASE}:sendOobCode?key=${API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ requestType: 'PASSWORD_RESET', email })
      });
      
      const data = await response.json();
      if (!response.ok) {
        throw new Error(data.error?.message || 'Failed to send reset link');
      }
    } catch (e: any) {
      console.error('FirebaseAuthRest sendPasswordReset error:', e);
      throw e;
    }
  }
};
