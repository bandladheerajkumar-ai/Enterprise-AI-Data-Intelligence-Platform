async function sendMessage() {

    const input =
        document.getElementById("question");

    const question =
        input.value.trim();

    if (!question) return;

    addMessage(
        question,
        "user-message"
    );

    input.value = "";

    const thinkingId =
        addMessage(
            "Thinking...",
            "bot-message"
        );

    try {

        const response =
            await fetch(
                "/query",
                {
                    method:"POST",

                    headers:{
                        "Content-Type":
                        "application/json"
                    },

                    body:JSON.stringify({
                        question:question
                    })
                }
            );

        const data =
            await response.json();

        removeMessage(thinkingId);

        addMessage(
            data.answer,
            "bot-message"
        );

    }
    catch(error){

        removeMessage(thinkingId);

        addMessage(
            "Something went wrong.",
            "bot-message"
        );
    }
}

function addMessage(text,className){

    const chatBox =
        document.getElementById(
            "chat-box"
        );

    const div =
        document.createElement(
            "div"
        );

    div.className = className;

    div.innerHTML = text.replace(/\n/g,"<br>");

    div.id =
        "msg-" + Date.now();

    chatBox.appendChild(div);

    chatBox.scrollTop =
        chatBox.scrollHeight;

    return div.id;
}

function removeMessage(id){

    const element =
        document.getElementById(id);

    if(element)
        element.remove();
}

function handleKeyPress(event){

    if(event.key === "Enter"){

        sendMessage();
    }
}