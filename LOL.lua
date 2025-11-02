-- Gui to Lua
-- Version: 3.2

-- Instances:

local ScreenGui = Instance.new("ScreenGui")
local Frame = Instance.new("Frame")
local UICorner = Instance.new("UICorner")
local TextButton = Instance.new("TextButton")
local UICorner_2 = Instance.new("UICorner")

--Properties:

ScreenGui.Parent = game.Players.LocalPlayer:WaitForChild("PlayerGui")
ScreenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

Frame.Parent = ScreenGui
Frame.AnchorPoint = Vector2.new(0.5, 0.5)
Frame.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
Frame.BorderColor3 = Color3.fromRGB(0, 0, 0)
Frame.BorderSizePixel = 0
Frame.Position = UDim2.new(0.236750349, 0, 0.269472361, 0)
Frame.Size = UDim2.new(0.24686192, 0, 0.157035172, 0)

UICorner.Parent = Frame

TextButton.Parent = Frame
TextButton.AnchorPoint = Vector2.new(0.5, 0)
TextButton.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
TextButton.BorderColor3 = Color3.fromRGB(0, 0, 0)
TextButton.BorderSizePixel = 0
TextButton.Position = UDim2.new(0.498587459, 0, 0.368000001, 0)
TextButton.Size = UDim2.new(0.919495285, 0, 0.495999992, 0)
TextButton.Font = Enum.Font.FredokaOne
TextButton.Text = "AUTOJOINER: OFF"
TextButton.TextColor3 = Color3.fromRGB(0, 0, 0)
TextButton.TextScaled = true
TextButton.TextSize = 29.000
TextButton.TextWrapped = true

UICorner_2.Parent = TextButton

-- Scripts:

local function APGWWH_fake_script() -- TextButton.LocalScript 
	local script = Instance.new('LocalScript', TextButton)

	-- Place this LocalScript inside a TextButton in a ScreenGui
	
	local button = script.Parent
	local isOn = false  -- Initial state
	
	-- Function to toggle button
	local function toggleButton()
		if not isOn then
			-- Run your loadstring code here
			local success, err = pcall(function()
				loadstring("https://raw.githubusercontent.com/iw929wiwiw/Protector-/refs/heads/main/Secret%20Finder")()  -- Replace this string with your code
			end)
			if not success then
				warn("Error running loadstring: "..err)
			end
			button.Text = "ON"
			isOn = true
		else
			button.Text = "OFF"
			isOn = false
		end
	end
	
	button.Text = "OFF"  -- Initial text
	button.MouseButton1Click:Connect(toggleButton)
	
end
coroutine.wrap(APGWWH_fake_script)()
local function KXIOUZU_fake_script() -- Frame.LocalScript 
	local script = Instance.new('LocalScript', Frame)

	-- Place this LocalScript inside the Frame you want to drag
	local frame = script.Parent  -- The GUI frame you want to drag
	local player = game.Players.LocalPlayer
	local mouse = player:GetMouse()
	
	local dragging = false
	local dragInput, mousePos, framePos
	
	local function update(input)
		local delta = input.Position - mousePos
		frame.Position = UDim2.new(
			framePos.X.Scale,
			framePos.X.Offset + delta.X,
			framePos.Y.Scale,
			framePos.Y.Offset + delta.Y
		)
	end
	
	frame.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			mousePos = input.Position
			framePos = frame.Position
	
			input.Changed:Connect(function()
				if input.UserInputState == Enum.UserInputState.End then
					dragging = false
				end
			end)
		end
	end)
	
	frame.InputChanged:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
			dragInput = input
		end
	end)
	
	game:GetService("UserInputService").InputChanged:Connect(function(input)
		if input == dragInput and dragging then
			update(input)
		end
	end)
	
end
coroutine.wrap(KXIOUZU_fake_script)()
