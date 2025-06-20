const functions = require('firebase-functions');
const axios = require('axios');

// Your FatSecret credentials
const FATSECRET_CLIENT_ID = functions.config().fatsecret?.client_id;
const FATSECRET_CLIENT_SECRET = functions.config().fatsecret?.client_secret;

// Helper function to get FatSecret access token
async function getFatSecretToken() {
  try {
    if (!FATSECRET_CLIENT_ID || !FATSECRET_CLIENT_SECRET) {
      throw new Error('FatSecret credentials not configured');
    }
    
    const credentials = Buffer.from(`${FATSECRET_CLIENT_ID}:${FATSECRET_CLIENT_SECRET}`).toString('base64');
    
    const response = await axios.post('https://oauth.fatsecret.com/connect/token', 
      'grant_type=client_credentials&scope=basic',
      {
        headers: {
          'Content-Type': 'application/x-www-form-urlencoded',
          'Authorization': `Basic ${credentials}`
        }
      }
    );
    
    return response.data.access_token;
  } catch (error) {
    console.error('Error getting FatSecret token:', error.response?.data || error.message);
    throw new functions.https.HttpsError('internal', 'Failed to authenticate with FatSecret');
  }
}

// Main function to search food by barcode
exports.searchFoodByBarcode = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }
  
  const {barcode} = data;
  
  if (!barcode) {
    throw new functions.https.HttpsError('invalid-argument', 'Barcode is required');
  }
  
  try {
    console.log(`Searching for barcode: ${barcode}`);
    
    const accessToken = await getFatSecretToken();
    console.log('Got FatSecret access token');
    
    const barcodeResponse = await axios.get('https://platform.fatsecret.com/rest/server.api', {
      params: {
        method: 'food.find_id_for_barcode',
        barcode: barcode,
        format: 'json'
      },
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });
    
    console.log('Barcode search response:', barcodeResponse.data);
    
    if (barcodeResponse.data.error) {
      console.log('FatSecret API error:', barcodeResponse.data.error);
      return {error: barcodeResponse.data.error};
    }
    
    if (!barcodeResponse.data.food_id?.value) {
      return {error: {message: 'No food found for this barcode'}};
    }
    
    const foodId = barcodeResponse.data.food_id.value;
    console.log(`Found food ID: ${foodId}`);
    
    const foodResponse = await axios.get('https://platform.fatsecret.com/rest/server.api', {
      params: {
        method: 'food.get.v2',
        food_id: foodId,
        format: 'json'
      },
      headers: {
        'Authorization': `Bearer ${accessToken}`
      }
    });
    
    console.log('Food details retrieved successfully');
    return {food: foodResponse.data.food};
    
  } catch (error) {
    console.error('Error in searchFoodByBarcode:', error.response?.data || error.message);
    throw new functions.https.HttpsError('internal', 'Failed to search for food');
  }
});
