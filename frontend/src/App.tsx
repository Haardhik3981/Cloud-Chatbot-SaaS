import { useEffect, useState } from "react";
import axios from "axios";

const COGNITO_DOMAIN = "https://chatbot-91d4966b.auth.us-west-2.amazoncognito.com"; 
const CLIENT_ID = "7omafgdpaj2lgrb7dj7h8h2b0f";
const REDIRECT_URI = "http://localhost:5173";

export default function App() {
  const [accessToken, setAccessToken] = useState(null);
  const [chatHistory, setChatHistory] = useState([]);

  useEffect(() => {
    const urlParams = new URLSearchParams(window.location.search);
    const code = urlParams.get("code");

    if (code && !sessionStorage.getItem("token_exchanged")) {
      exchangeCodeForToken(code);
    }
    if (!code) {
      console.log("No code present — normal page load.");
    }
  }, []);

  const exchangeCodeForToken = async (code) => {
    try {
      const params = new URLSearchParams();
      params.append("grant_type", "authorization_code");
      params.append("client_id", CLIENT_ID);
      params.append("code", code);
      params.append("redirect_uri", REDIRECT_URI);

      const response = await axios.post(
        `${COGNITO_DOMAIN}/oauth2/token`,
        params,
        {
          headers: {
            "Content-Type": "application/x-www-form-urlencoded",
          },
        }
      );

      console.log("Tokens:", response.data);
      setAccessToken(response.data.access_token);
      window.history.replaceState({}, document.title, "/");
    } catch (error) {
      console.error("Token exchange failed:", error);
    }
  };

  const handleLogin = () => {
    window.location.href = `${COGNITO_DOMAIN}/login?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}`;
  };

  const callProtectedApi = async () => {
    if (!accessToken) {
      alert("No token available");
      return;
    }
    try {
      const apiUrl = "https://rmgio2nkw5.execute-api.us-west-2.amazonaws.com/chat"; // Replace with terraform output
      const response = await axios.post(
        apiUrl,
        { message: "Hello from frontend" },
        {
          headers: {
            Authorization: `Bearer ${accessToken}`,
          },
        }
      );
      console.log("API response:", response.data);
    } catch (error) {
      console.error("API call failed:", error);
    }
  };

  const fetchChatHistory = async () => {
    if (!accessToken) {
      alert("No token available");
      return;
    }
    try {
      const apiUrl = "https://rmgio2nkw5.execute-api.us-west-2.amazonaws.com/chat-history"; // Replace with terraform output
      const response = await axios.get(apiUrl, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });
      console.log("Chat history:", response.data);
      setChatHistory(response.data.chat_history || []);
    } catch (error) {
      console.error("Fetching chat history failed:", error);
    }
  };

  return (
    <div className="flex flex-col gap-4 p-4">
      {!accessToken ? (
        <button onClick={handleLogin} className="bg-blue-600 text-white p-2 rounded-lg">
          Login with Cognito
        </button>
      ) : (
        <>
        <button onClick={callProtectedApi} className="bg-green-600 text-white p-2 rounded-lg">
          Call Secured Chat API
        </button>
        <button onClick={fetchChatHistory} className="bg-purple-600 text-white p-2 rounded-lg">
          Fetch Chat History
        </button>
        <div className="mt-4">
          {chatHistory.map((item, index) => (
            <div key={index} className="p-2 border-b">
              {item.timestamp} — {item.message}
            </div>
          ))}
        </div>
        </>
      )}
    </div>
  );
}