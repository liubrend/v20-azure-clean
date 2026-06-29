// Production environment. The deploy-frontend workflow replaces __API_BASE_URL__
// with the real api-gateway host before `ng build`.
export const environment = {
  production: true,
  apiBaseUrl: '__API_BASE_URL__',
};
