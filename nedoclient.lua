--я пидорас
--v1
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")

local SERVER_URL = "https://kchat-4uub.onrender.com" -- если ты сольёшь этот url роскомнадзору...
local POLL_INTERVAL = 1.35  -- кд проверки сообщений


local function httpRequest(url, method, body)
    local httpFunc = request or http_request
    if not httpFunc then
        error("HTTP нету, юзай норм инжектор")
    end

    local response = httpFunc({
        Url = url,
        Method = method,
        Headers = { ["Content-Type"] = "application/json" },
        Body = body and HttpService:JSONEncode(body) or nil
    })

    if response.StatusCode == 200 then
        return HttpService:JSONDecode(response.Body)
    else
        error("HTTP " .. tostring(response.StatusCode) .. " " .. tostring(response.Body))
    end
end

--гуишка
local function createGUI()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "kChatHTTP"
    screenGui.Parent = CoreGui

    local frame = Instance.new("Frame")
    frame.Name = "MainFrame"
    frame.Size = UDim2.new(0, 320, 0, 240)
    frame.Position = UDim2.new(0, 20, 0, 150)
    frame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
    frame.BackgroundTransparency = 0.3
    frame.BorderSizePixel = 0
    frame.Active = true
    frame.Draggable = true
    frame.Parent = screenGui

    local titleLabel = Instance.new("TextLabel")
    titleLabel.Name = "Title"
    titleLabel.Size = UDim2.new(1, 0, 0, 22)
    titleLabel.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    titleLabel.Text = "kChat"
    titleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    titleLabel.Font = Enum.Font.SourceSansBold
    titleLabel.TextSize = 14
    titleLabel.Parent = frame

    local messageList = Instance.new("ScrollingFrame")
    messageList.Name = "Messages"
    messageList.Size = UDim2.new(1, -6, 0, 175)
    messageList.Position = UDim2.new(0, 3, 0, 25)
    messageList.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
    messageList.BackgroundTransparency = 0.5
    messageList.BorderSizePixel = 0
    messageList.CanvasSize = UDim2.new(0, 0, 0, 0)
    messageList.ScrollBarThickness = 6
    messageList.Parent = frame

    local uiListLayout = Instance.new("UIListLayout")
    uiListLayout.Parent = messageList
    uiListLayout.SortOrder = Enum.SortOrder.LayoutOrder
    uiListLayout.Padding = UDim.new(0, 2)

    local inputFrame = Instance.new("Frame")
    inputFrame.Name = "InputArea"
    inputFrame.Size = UDim2.new(1, -6, 0, 28)
    inputFrame.Position = UDim2.new(0, 3, 0, 205)
    inputFrame.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
    inputFrame.BackgroundTransparency = 0.3
    inputFrame.BorderSizePixel = 0
    inputFrame.Parent = frame

    local textBox = Instance.new("TextBox")
    textBox.Name = "Input"
    textBox.Size = UDim2.new(1, -6, 1, 0)
    textBox.Position = UDim2.new(0, 3, 0, 0)
    textBox.BackgroundTransparency = 1
    textBox.Text = ""
    textBox.PlaceholderText = "Введите сообщение..."
    textBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    textBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 150)
    textBox.Font = Enum.Font.SourceSans
    textBox.TextSize = 14
    textBox.Parent = inputFrame

    local toggleButton = Instance.new("TextButton")
    toggleButton.Name = "Toggle"
    toggleButton.Size = UDim2.new(0, 20, 0, 22)
    toggleButton.Position = UDim2.new(1, -22, 0, 0)
    toggleButton.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    toggleButton.Text = "-"
    toggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toggleButton.Font = Enum.Font.SourceSansBold
    toggleButton.TextSize = 14
    toggleButton.Parent = frame

    local minimized = false
    toggleButton.MouseButton1Click:Connect(function()
        minimized = not minimized
        if minimized then
            frame.Size = UDim2.new(0, 320, 0, 28)
            messageList.Visible = false
            inputFrame.Visible = false
            toggleButton.Text = "+"
        else
            frame.Size = UDim2.new(0, 320, 0, 240)
            messageList.Visible = true
            inputFrame.Visible = true
            toggleButton.Text = "-"
        end
    end)

    return screenGui, messageList, textBox, titleLabel
end

--локальные сообщения
local function addMessage(messageList, text, color)
    local label = Instance.new("TextLabel")
    local indx
    if #text < 30 then
        label.Size = UDim2.new(1, -10, 0, 18)
        indx = 18
    elseif #text > 30 and #text < 60 then
        label.Size = UDim2.new(1, -10, 0, 36)
        indx = 36
    elseif #text > 60 then
        label.Size = UDim2.new(1, -10, 0, 54)
        indx = 54
    end
    label.BackgroundTransparency = 1
    label.Text = text
    label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
    label.Font = Enum.Font.SourceSans
    label.TextSize = 14
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.TextWrapped = true
    label.RichText = false
    label.Parent = messageList

    messageList.CanvasSize = UDim2.new(0, 0, 0, messageList.CanvasSize.Y.Offset + 20)
    messageList.CanvasPosition = Vector2.new(0, math.max(0, messageList.CanvasSize.Y.Offset - messageList.AbsoluteSize.Y))
end

--глав функция
local function startChat()
    local screenGui, messageList, textBox, titleLabel = createGUI()
    local player = Players.LocalPlayer
    local userId = player.UserId
    local playerName = player.Name
    local lastMessageId = DateTime.now().UnixTimestampMillis

    --показ сообщений
    local function sendMessage(text)
        local ok, err = pcall(function()
            return httpRequest(SERVER_URL .. "/send", "POST", {
                userId = userId,
                name = playerName,
                text = text
            })
        end)
        if not ok then
            addMessage(messageList, "Ошибка: " .. tostring(err), Color3.fromRGB(255, 100, 100))
        end
    end

    --отправка
    textBox.FocusLost:Connect(function(enterPressed)
        if enterPressed then
            local text = textBox.Text:match("^%s*(.-)%s*$")  -- обрезаем пробелы
            if text ~= "" then
                sendMessage(text)
                textBox.Text = ""
            end
        end
    end)

    --великий костыль (polling)
    spawn(function()
        while true do
            local ok, data = pcall(function()
                return httpRequest(SERVER_URL .. "/messages?since=" .. tostring(lastMessageId), "GET")
            end)
            if ok and data and data.messages then
                for _, msg in ipairs(data.messages) do
                    if msg.id > lastMessageId then
                        lastMessageId = msg.id
                        local prefix, color
                        if msg.userId == "system" then
                            prefix = "🔹"
                            color = Color3.fromRGB(180, 180, 180)
                        else
                            prefix = "[" .. msg.name .. "]: "
                            color = Color3.fromRGB(200, 200, 255)
                            pcall(function()
	                            game.TextChatService:DisplayBubble(workspace:FindFirstChild(msg.name),msg.text)
                            end)          
                        end
                        addMessage(messageList, prefix .. msg.text, color)
                    end
                end
            end
            wait(POLL_INTERVAL)
        end
    end)

    addMessage(messageList, "Чат работает на костылях и на бесплатном хостинге серверов, подключение может занять минуту...", Color3.fromRGB(128, 128, 128))

    success,response = pcall(function()
        httpRequest(SERVER_URL .. "/join", "POST", {
            userId = userId,
            name = playerName
        })
    end)

    if success then
        addMessage(messageList, "Подключение к чату успешно!", Color3.fromRGB(100, 255, 100))
    end

end

--запуск
if Players.LocalPlayer then
    startChat()
else
    Players.PlayerAdded:Wait()
    wait(0.5)
    startChat()
end
