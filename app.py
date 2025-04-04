import streamlit as st
import os
import openai
from PIL import Image
import io
import fitz  # PyMuPDF
import base64

# --- Configuration ---

# Azure API version (update as needed)
api_version = "2024-02-01"

# Dictionary mapping friendly model names to Azure deployment names
# IMPORTANT: Replace placeholders with your actual Azure deployment names!
MODEL_DEPLOYMENTS = {
    "Deepseek-R1": "DeepSeek-R1",
    "GPT-3.5 Turbo": "gpt-35-turbo",
    "GPT-4o": "gpt-4o",
    "O3 Mini": "o3-mini"
}

# --- Helper Functions ---

def encode_image_to_base64(image_file):
    """Encodes an uploaded image file to base64."""
    image_bytes = image_file.read()
    return base64.b64encode(image_bytes).decode('utf-8')

def extract_text_from_txt(uploaded_file):
    """Extracts text from an uploaded text file."""
    return uploaded_file.getvalue().decode("utf-8")

def extract_text_from_pdf(uploaded_file):
    """Extracts text from an uploaded PDF file."""
    try:
        pdf_document = fitz.open(stream=uploaded_file.getvalue(), filetype="pdf")
        text = ""
        for page_num in range(len(pdf_document)):
            page = pdf_document.load_page(page_num)
            text += page.get_text()
        return text
    except Exception as e:
        st.error(f"Error reading PDF: {e}")
        return None

def process_uploaded_file(uploaded_file):
    """Processes the uploaded file based on its type."""
    file_details = {"filename": uploaded_file.name, "filetype": uploaded_file.type, "filesize": uploaded_file.size}
    st.sidebar.write("Uploaded File Details:")
    st.sidebar.json(file_details)

    if uploaded_file.type == "text/plain":
        return {"type": "text", "content": extract_text_from_txt(uploaded_file)}
    elif uploaded_file.type == "application/pdf":
        text_content = extract_text_from_pdf(uploaded_file)
        return {"type": "text", "content": text_content} if text_content else None
    elif uploaded_file.type.startswith("image/"):
        try:
            image = Image.open(uploaded_file)
            st.sidebar.image(image, caption=f"Uploaded Image: {uploaded_file.name}", use_container_width=True)
            uploaded_file.seek(0)
            base64_image = encode_image_to_base64(uploaded_file)
            return {"type": "image", "content": base64_image, "mime_type": uploaded_file.type}
        except Exception as e:
            st.error(f"Error processing image: {e}")
            return None
    else:
        st.sidebar.error("Unsupported file type.")
        return None

# --- Streamlit UI Setup ---

st.set_page_config(layout="wide", page_title="Azure AI Foundry Chat")
st.title("💬 Chat with Azure AI Foundry Models")

with st.sidebar:
    st.header("Configuration")

    st.subheader("Azure Credentials")
    azure_endpoint_input = st.text_input(
        "Azure OpenAI Endpoint",
        value=os.getenv("AZURE_OPENAI_ENDPOINT", "<YOUR_AZURE_ENDPOINT>")
    )
    api_key_input = st.text_input(
        "Azure OpenAI API Key",
        value=os.getenv("AZURE_OPENAI_API_KEY", "<YOUR_API_KEY>"),
        type="password"
    )

    if not api_key_input or not azure_endpoint_input or "<YOUR_" in api_key_input or "<YOUR_" in azure_endpoint_input:
        st.warning("Please enter your Azure OpenAI Endpoint and API Key.")
        st.stop()

    st.subheader("Model Selection")
    selected_model_name = st.selectbox(
        "Choose a model:",
        options=list(MODEL_DEPLOYMENTS.keys())
    )
    selected_deployment_name = MODEL_DEPLOYMENTS[selected_model_name]

    st.subheader("Context Upload")
    uploaded_file = st.file_uploader(
        "Upload Context (Text, PDF, Image)",
        type=["txt", "pdf", "png", "jpg", "jpeg"]
    )

    file_data = None 
    if uploaded_file:
        if "uploaded_file_name" not in st.session_state or st.session_state.uploaded_file_name != uploaded_file.name:
            st.session_state.uploaded_file_name = uploaded_file.name
            with st.spinner("Processing file..."):
                st.session_state.file_data = process_uploaded_file(uploaded_file)
        file_data = st.session_state.get("file_data", None)
        if file_data:
            st.info(f"Context from {file_data['type']} file loaded.")
    else:
        st.session_state.file_data = None
        st.session_state.uploaded_file_name = None

    if st.button("Clear Chat History"):
        st.session_state.messages = []
        st.session_state.file_data = None
        st.session_state.uploaded_file_name = None
        st.rerun()

# --- Azure OpenAI Client Initialization ---

try:
    client = openai.AzureOpenAI(
        api_key=api_key_input,
        azure_endpoint=azure_endpoint_input,
        api_version=api_version, 
    )
except Exception as e:
    st.error(f"Failed to initialize Azure OpenAI client: {e}")
    st.warning("Please ensure your Endpoint and API Key are correct and the API version is supported.")
    st.stop()

# --- Chat Interaction ---

if "messages" not in st.session_state:
    st.session_state.messages = []

for message in st.session_state.messages:
    with st.chat_message(message["role"]):
        st.markdown(message["content"])

if prompt := st.chat_input("What would you like to ask?"):
    with st.chat_message("user"):
        st.markdown(prompt)
        current_file_data = st.session_state.get("file_data", None)
        if current_file_data and current_file_data["type"] == "image" and not any(isinstance(msg["content"], list) for msg in st.session_state.get("messages", [])):
            st.image(f"data:{current_file_data['mime_type']};base64,{current_file_data['content']}")

    messages_for_api = []
    base_system_prompt = "You are a helpful assistant with a bit of witty style."
    messages_for_api.append({"role": "system", "content": base_system_prompt})

    current_file_data = st.session_state.get("file_data", None)
    user_content_for_api = [{"type": "text", "text": prompt}]

    if current_file_data:
        if current_file_data["type"] == "text":
            messages_for_api.append({"role": "system", "content": f"Also consider the following text context:\n{current_file_data['content']}"})
        elif current_file_data["type"] == "image" and selected_model_name == "GPT-4o":
            image_url = f"data:{current_file_data['mime_type']};base64,{current_file_data['content']}"
            user_content_for_api.append({"type": "image_url", "image_url": {"url": image_url}})
            st.info("Image data sent to GPT-4o.") 
        elif current_file_data["type"] == "image":
            st.warning(f"The selected model ({selected_model_name}) might not support image analysis. Sending only the text prompt.")

    history_messages = [msg for msg in st.session_state.messages if msg["role"] in ["user", "assistant"]]
    messages_for_api.extend(history_messages)
    messages_for_api.append({"role": "user", "content": user_content_for_api})

    st.session_state.messages.append({"role": "user", "content": user_content_for_api})

    with st.chat_message("assistant"):
        message_placeholder = st.empty()
        full_response = ""
        try:
            response = client.chat.completions.create(
                model=selected_deployment_name,
                messages=messages_for_api,
                stream=True 
            )

            for chunk in response:
                if chunk.choices:
                    content = chunk.choices[0].delta.content
                    if content:
                        full_response += content
                        message_placeholder.markdown(full_response + "▌")

            message_placeholder.markdown(full_response)
            st.session_state.messages.append({"role": "assistant", "content": full_response})

        except Exception as e:
            st.error(f"An error occurred: {e}")
