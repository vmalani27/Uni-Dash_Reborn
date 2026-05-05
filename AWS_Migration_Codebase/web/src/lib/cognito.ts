import {
  CognitoUserPool,
  CognitoUser,
  AuthenticationDetails,
  CognitoUserAttribute,
  CognitoUserSession,
} from 'amazon-cognito-identity-js';

let _userPool: CognitoUserPool | null = null;

const getUserPool = (): CognitoUserPool => {
  if (!_userPool) {
    const poolId = process.env.NEXT_PUBLIC_COGNITO_USER_POOL_ID || '';
    const clientId = process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID || '';

    if (!poolId || !clientId || poolId === 'null' || clientId === 'null') {
      throw new Error('Cognito not configured. Set NEXT_PUBLIC_COGNITO_USER_POOL_ID and NEXT_PUBLIC_COGNITO_CLIENT_ID.');
    }

    _userPool = new CognitoUserPool({
      UserPoolId: poolId,
      ClientId: clientId,
    });
  }
  return _userPool;
};

export const signUp = (email: string, password: string): Promise<any> => {
  return new Promise((resolve, reject) => {
    const attributeList: CognitoUserAttribute[] = [
      new CognitoUserAttribute({ Name: 'email', Value: email }),
    ];

    getUserPool().signUp(email, password, attributeList, [], (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
};

export const confirmSignUp = (email: string, code: string): Promise<any> => {
  return new Promise((resolve, reject) => {
    const cognitoUser = new CognitoUser({
      Username: email,
      Pool: getUserPool(),
    });

    cognitoUser.confirmRegistration(code, true, (err, result) => {
      if (err) reject(err);
      else resolve(result);
    });
  });
};

export const signIn = (email: string, password: string): Promise<any> => {
  return new Promise((resolve, reject) => {
    const cognitoUser = new CognitoUser({
      Username: email,
      Pool: getUserPool(),
    });

    const authenticationDetails = new AuthenticationDetails({
      Username: email,
      Password: password,
    });

    cognitoUser.authenticateUser(authenticationDetails, {
      onSuccess: (session) => {
        cognitoUser.setSignInUserSession(session);
        resolve(session);
      },
      onFailure: (err) => reject(err),
    });
  });
};

export const signOut = (): void => {
  const pool = getUserPool();
  const cognitoUser = pool.getCurrentUser();
  if (cognitoUser) {
    cognitoUser.signOut();
  }
  localStorage.removeItem("idToken");
};

export const getCurrentUser = (): CognitoUser | null => {
  try {
    return getUserPool().getCurrentUser();
  } catch {
    return null;
  }
};

export const getCurrentUserSession = (): Promise<CognitoUserSession | null> => {
  return new Promise((resolve) => {
    let cognitoUser: CognitoUser | null = null;
    try {
      cognitoUser = getUserPool().getCurrentUser();
    } catch {
      resolve(null);
      return;
    }

    if (!cognitoUser) {
      resolve(null);
      return;
    }

    cognitoUser.getSession((err: any, session: any) => {
      if (err) { resolve(null); return; }
      if (session && session.isValid()) {
        resolve(session);
      } else {
        resolve(null);
      }
    });
  });
};

export const getCurrentUserToken = async (): Promise<string | null> => {
  const session = await getCurrentUserSession();
  if (!session) return null;
  return session.getAccessToken().getJwtToken();
};

export const getCurrentUserIdToken = async (): Promise<string | null> => {
  const session = await getCurrentUserSession();
  if (!session) return null;
  return session.getIdToken().getJwtToken();
};

export const isUserLoggedIn = (): Promise<boolean> => {
  return new Promise((resolve) => {
    let cognitoUser: CognitoUser | null = null;
    try {
      cognitoUser = getUserPool().getCurrentUser();
    } catch {
      resolve(false);
      return;
    }

    if (!cognitoUser) {
      resolve(false);
      return;
    }

    cognitoUser.getSession((err: any, session: any) => {
      if (err || !session || !session.isValid()) {
        resolve(false);
      } else {
        resolve(true);
      }
    });
  });
};
