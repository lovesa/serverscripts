<?php
error_reporting(0);

class AccessTokenAuthentication {
    /*
     * Get the access token.
     *
     * @param string $grantType    Grant type.
     * @param string $scopeUrl     Application Scope URL.
     * @param string $clientID     Application client ID.
     * @param string $clientSecret Application client ID.
     * @param string $authUrl      Oauth Url.
     *
     * @return string.
     */
    function getTokens($grantType, $scopeUrl, $clientID, $clientSecret, $authUrl){
        try {
            //Initialize the Curl Session.
            $ch = curl_init();
            //Create the request Array.
            $paramArr = array (
             'grant_type'    => $grantType,
             'scope'         => $scopeUrl,
             'client_id'     => $clientID,
             'client_secret' => $clientSecret
            );
            //Create an Http Query.//
            $paramArr = http_build_query($paramArr);
            //Set the Curl URL.
            curl_setopt($ch, CURLOPT_URL, $authUrl);
            //Set HTTP POST Request.
            curl_setopt($ch, CURLOPT_POST, TRUE);
            //Set data to POST in HTTP "POST" Operation.
            curl_setopt($ch, CURLOPT_POSTFIELDS, $paramArr);
            //CURLOPT_RETURNTRANSFER- TRUE to return the transfer as a string of the return value of curl_exec().
            curl_setopt ($ch, CURLOPT_RETURNTRANSFER, TRUE);
            //CURLOPT_SSL_VERIFYPEER- Set FALSE to stop cURL from verifying the peer's certificate.
            curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
            //Execute the  cURL session.
            $strResponse = curl_exec($ch);
            //Get the Error Code returned by Curl.
            $curlErrno = curl_errno($ch);
            if($curlErrno){
                $curlError = curl_error($ch);
                throw new Exception($curlError);
            }
            //Close the Curl Session.
            curl_close($ch);
            //Decode the returned JSON string.
            $objResponse = json_decode($strResponse);

            if ($objResponse->error){
                throw new Exception($objResponse->error_description);
            }
            return $objResponse->access_token;
        } catch (Exception $e) {
            echo "Exception-".$e->getMessage();
        }
    }
}

/*
 * Class:AccessTokenAuthentication
 *
 * Create SOAP Object.
 */
class SOAPMicrosoftTranslator {
    /*
     * Soap Object.
     *
     * @var ObjectArray.
     */
    public $objSoap;
    /*
     * Create the SAOP object.
     *
     * @param string $accessToken Access Token string.
     * @param string $wsdlUrl     WSDL string.
     *
     * @return string.
     */
    public function __construct($accessToken, $wsdlUrl){
        try {
            //Authorization header string.
            $authHeader = "Authorization: Bearer ". $accessToken;
            $contextArr = array(
                'http'   => array(
                    'header' => $authHeader
            )
            );
            //Create a streams context.
            $objContext = stream_context_create($contextArr);
            $optionsArr = array (
                'soap_version'   => 'SOAP_1_2',
                'encoding'          => 'UTF-8',
                'exceptions'      => true,
                'trace'          => true,
                'cache_wsdl'     => 'WSDL_CACHE_NONE',
                'stream_context' => $objContext,
                'user_agent'     => 'PHP-SOAP/'.PHP_VERSION."\r\n".$authHeader
            );
            //Call Soap Client.
            $this->objSoap = new SoapClient($wsdlUrl, $optionsArr);
        } catch(Exception $e){
            echo "<h2>Exception Error!</h2>";
            echo $e->getMessage();
        }
    }
}

try {
    //Soap WSDL Url
    $wsdlUrl       = "http://api.microsofttranslator.com/V2/Soap.svc";
    //Client ID of the application.
    $clientID       = "aleks_translator";
    //Client Secret key of the application.
    $clientSecret = "UQReWPAR6YGvPmAxlyvtDEQC66Tw71zoUe5hX54odJ0=";
    //OAuth Url.
    $authUrl      = "https://datamarket.accesscontrol.windows.net/v2/OAuth2-13/";
    //Application Scope Url
    $scopeUrl     = "http://api.microsofttranslator.com";
    //Application grant type
    $grantType    = "client_credentials";

    //Create the Authentication object
    $authObj      = new AccessTokenAuthentication();
    //Get the Access token
    $accessToken  = $authObj->getTokens($grantType, $scopeUrl, $clientID, $clientSecret, $authUrl);
    //Create soap translator Object
    $soapTranslator = new SOAPMicrosoftTranslator($accessToken, $wsdlUrl);

    //Set the params.
    $fromLanguage = "en";
    $toLanguage   = "pl";
    include './Poland.php';

    //$inputStrArr     = array("The answer lies in machine translation", "the best machine translation technology cannot always provide translations tailored to a site or users like a human", "Simply copy and paste a code snippet anywhere");
    $pos=1755;
    $lim=250;

    $k=0;
    foreach ($lang as $str) {
       if($k>=$pos) {
            $inputStrArr[] = $str;
       }


       if($k==($pos+$lim))
        break;

       $k++;
    }

    //Optional argument list.
    $optionArg = array (
        'category'    => "general",
        'ContentType' => "text/plain",
        'Uri'         => 'all',
        'User'        => 'all'
    );

    //Request argument list.
    $requestArg = array (
         'texts'   => $inputStrArr,
         'from'    => $fromLanguage,
         'to'      => $toLanguage,
         'options' => $optionArg
    );

    $i=$pos;

    $keys = array_keys($lang);

     $response = $soapTranslator->objSoap->TranslateArray($requestArg);

    foreach( $response->TranslateArrayResult->TranslateArrayResponse as $translatedRes) {
        echo "\t'".$keys[$i]."' => '".$translatedRes->TranslatedText."',\n";
        $i++;
    }
    echo "///////////////";

} catch (Exception $e) {
    echo "Exception: " . $e->getMessage() . "<br/>";
}

