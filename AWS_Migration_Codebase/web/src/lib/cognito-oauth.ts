export const getGoogleConnectUrl = (state?: string) => {
  const params = new URLSearchParams();
  params.set('response_type', 'code');
  params.set('client_id', process.env.NEXT_PUBLIC_COGNITO_CLIENT_ID || '');
  params.set('redirect_uri', process.env.NEXT_PUBLIC_COGNITO_CALLBACK_URL || '');
  params.set('scope', 'openid email profile');
  params.set('identity_provider', 'Google');
  params.set('idp_identifier', 'Google');
  if (state) params.set('state', state);

  const domain = process.env.NEXT_PUBLIC_COGNITO_DOMAIN || '';
  return `https://${domain}/oauth2/authorize?${params.toString()}`;
};
