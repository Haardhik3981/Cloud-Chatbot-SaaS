
import { useEffect, useState, useRef } from "react";
import axios from "axios";

const COGNITO_DOMAIN = "https://chatbot-91d4966b.auth.us-west-2.amazoncognito.com"; 
const CLIENT_ID = "7omafgdpaj2lgrb7dj7h8h2b0f";
const REDIRECT_URI = "http://localhost:5173";
//http://localhost:5173
//https://d3pb94cafp68vt.cloudfront.net
//https://chatbot-91d4966b.auth.us-west-2.amazoncognito.com/login?response_type=code&client_id=7omafgdpaj2lgrb7dj7h8h2b0f&redirect_uri=http://localhost:3000

export default function App() {
  const [accessToken, setAccessToken] = useState(null);
  const [chatHistory, setChatHistory] = useState<{ role: string; message: string }[]>([]);
  const [inputMessage, setInputMessage] = useState("");
  const chatEndRef = useRef<HTMLDivElement | null>(null);


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
  useEffect(() => {
    if (chatEndRef.current) {
      chatEndRef.current.scrollIntoView({ behavior: 'smooth' });
    }
  }, [chatHistory])

  const exchangeCodeForToken = async (code: string) => {
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
      fetchChatHistory(response.data.access_token);
      window.history.replaceState({}, document.title, "/");
    } catch (error) {
      console.error("Token exchange failed:", error);
    }
  };

  const handleLogin = () => {
    window.location.href = `${COGNITO_DOMAIN}/login?response_type=code&client_id=${CLIENT_ID}&redirect_uri=${REDIRECT_URI}`;
  };
  const handleLogout = () => {
    setAccessToken(null);
    setChatHistory([]);
    window.location.href = `${COGNITO_DOMAIN}/logout?client_id=${CLIENT_ID}&logout_uri=${REDIRECT_URI}`;
  };

  const sendMessage = async () => {
  if (!accessToken || !inputMessage.trim()) return;
  try {
    const apiUrl = "https://rmgio2nkw5.execute-api.us-west-2.amazonaws.com/chat";
    const response = await axios.post(
      apiUrl,
      { message: inputMessage },
      {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      }
    );
    setChatHistory((prev) => [
      ...prev,
      { role: "user", message: inputMessage },
      { role: "bot", message: response.data.chatbot_reply }
    ]);
    setInputMessage("");
  } catch (error) {
    console.error("API call failed:", error);
  }
};


  const fetchChatHistory = async (token = accessToken) => {
    if (!token) {
      alert("No token available");
      return;
    }
    try {
      const apiUrl = "https://rmgio2nkw5.execute-api.us-west-2.amazonaws.com/chat-history"; // Replace with terraform output
      const response = await axios.get(apiUrl, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      });
      console.log("Chat history:", response.data);
      setChatHistory(response.data.chat_history || []);
    } catch (error) {
      console.error("Fetching chat history failed:", error);
    }
  };

  const clearChatHistory = async () => {
    if (!accessToken) return;
    try {
      const apiUrl = "https://rmgio2nkw5.execute-api.us-west-2.amazonaws.com/clear-chat";
      await axios.post(apiUrl, {}, {
        headers: {
          Authorization: `Bearer ${accessToken}`,
        },
      });
      setChatHistory([]);
    } catch (error) {
      console.error("Clearing chat history failed:", error);
    }
  };

  return (
    <div className="flex flex-col justify-center items-center min-h-screen bg-white p-4">
      <div className="w-full max-w-md flex flex-col gap-2 bg-white border rounded-lg shadow-lg p-4">
        {!accessToken ? (
          <button onClick={handleLogin} className="bg-blue-600 text-white p-2 rounded-lg">
            Login with Cognito
          </button>
        ) : (
          <>
          <div className="flex flex-col gap-2">
            <button onClick={handleLogout} className="bg-gray-600 text-white p-2 rounded-lg">
              Logout
            </button>

            <div className="flex-1 overflow-y-auto border p-2 min-h-[300px] max-h-[70vh]">
              {chatHistory.map((item, index) => (
                <div key={index} className={`flex ${item.role === "user" ? "justify-end" : "justify-start"}`}>
                  <div className={`p-2 rounded-2xl my-1 shadow-md max-w-[75%] ${item.role === "user" ? "bg-blue-500 text-white" : "bg-gray-200 text-gray-900"}`}>
                    {item.message}
                  </div>
                </div>
              ))}
            </div>
            <div className="flex gap-2">
              <input
                value={inputMessage}
                onChange={(e) => setInputMessage(e.target.value)}
                className="flex-grow border rounded-lg p-2"
                placeholder="Type your massage..."
              />
              <button onClick={sendMessage} className="bg-green-600 text-white p-2 rounded-lg">
                Send
              </button>
            </div>
          </div>
        <button onClick={clearChatHistory} className="bg-red-600 text-white p-2 rounded-lg">
          Clear Chat History
        </button>
          </>
        )}
      </div>
    </div>
  );
}