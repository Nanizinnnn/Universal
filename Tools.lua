--[[
 .____                  ________ ___.    _____                           __                
 |    |    __ _______   \_____  \\_ |___/ ____\_ __  ______ ____ _____ _/  |_  ___________ 
 |    |   |  |  \__  \   /   |   \| __ \   __\  |  \/  ___// ___\\__  \\   __\/  _ \_  __ \
 |    |___|  |  // __ \_/    |    \ \_\ \  | |  |  /\___ \\  \___ / __ \|  | (  <_> )  | \/
 |_______ \____/(____  /\_______  /___  /__| |____//____  >\___  >____  /__|  \____/|__|   
         \/          \/         \/    \/                \/     \/     \/                   
          \_Welcome to LuaObfuscator.com   (Alpha 0.10.9) ~  Much Love, Ferib 

]]--

local Players = game:GetService("Players");
local RunService = game:GetService("RunService");
local Camera = workspace.CurrentCamera;
local LocalPlayer = Players.LocalPlayer;
local UserInputService = game:GetService("UserInputService");
local CONFIG = {AimbotEnabled=false,ESPEnabled=false,AimbotSmoothing=0.75,ESPColor=Color3.new(0, 1, 0),FOVRadius=80,WallCheckEnabled=true,TeamCheckEnabled=true,HeadOffsetY=-0.3,HitboxExpanderEnabled=false,HitboxSize=5,HitboxTransparency=0.9,WalkSpeedEnabled=false,WalkSpeed=16};
local ESPDrawings = {};
local FOVCircle = nil;
local ExpandedHeads = {};
local WalkSpeedLoop = nil;
local UIMinimized = false;
local MainUI = nil;
local UIContent = nil;
local AimbotStatusLabel = nil;
local AimbotButton = nil;
local ESPStatusLabel = nil;
local ESPButton = nil;
local TeamCheckButton = nil;
local TeamCheckLabel = nil;
local WalkSpeedButton = nil;
local WalkSpeedLabel = nil;
local SmoothSlider = nil;
local SmoothLabel = nil;
local FOVSlider = nil;
local FOVLabel = nil;
local HitboxExpanderLabel = nil;
local HitboxExpanderButton = nil;
local HitboxSizeSlider = nil;
local HitboxSizeLabel = nil;
local HitboxTransparencySlider = nil;
local HitboxTransparencyLabel = nil;
local WalkSpeedSlider = nil;
local WalkSpeedSliderLabel = nil;
local function IsSameTeam(player1, player2)
	if not CONFIG.TeamCheckEnabled then
		return false;
	end
	if (not player1 or not player2) then
		return false;
	end
	if (player1.Team and player2.Team) then
		return player1.Team == player2.Team;
	end
	if (player1:FindFirstChild("Team") and player2:FindFirstChild("Team")) then
		return player1.Team.Name == player2.Team.Name;
	end
	return false;
end
local function IsVisible(targetHead)
	if not CONFIG.WallCheckEnabled then
		return true;
	end
	if not LocalPlayer.Character then
		return false;
	end
	local origin = Camera.CFrame.Position;
	local direction = targetHead.Position - origin;
	local distance = direction.Magnitude;
	if (distance < 0.1) then
		return true;
	end
	local raycastParams = RaycastParams.new();
	raycastParams.FilterType = Enum.RaycastFilterType.Exclude;
	raycastParams.FilterDescendantsInstances = {LocalPlayer.Character};
	local result = workspace:Raycast(origin, direction.Unit * distance, raycastParams);
	if result then
		local hitModel = result.Instance:FindFirstAncestorWhichIsA("Model");
		return hitModel == targetHead.Parent;
	end
	return true;
end
local function IsPlayerAlive(player)
	if (not player or not player.Character) then
		return false;
	end
	if (player == LocalPlayer) then
		return false;
	end
	if IsSameTeam(LocalPlayer, player) then
		return false;
	end
	local humanoid = player.Character:FindFirstChildOfClass("Humanoid");
	return humanoid and (humanoid.Health > 0);
end
local function GetAllPlayers()
	local alivePlayers = {};
	for _, player in ipairs(Players:GetPlayers()) do
		if IsPlayerAlive(player) then
			table.insert(alivePlayers, player);
		end
	end
	return alivePlayers;
end
local function GetNearestPlayerInFOV()
	local players = GetAllPlayers();
	if (#players == 0) then
		return nil;
	end
	local nearestPlayer = nil;
	local nearestDistance = math.huge;
	local screenCenter = Vector2.new(Camera.ViewportSize.X / 2, Camera.ViewportSize.Y / 2);
	for _, player in ipairs(players) do
		local head = player.Character:FindFirstChild("Head");
		if head then
			local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position);
			if (onScreen and (screenPos.Z > 0)) then
				local distance = (Vector2.new(screenPos.X, screenPos.Y) - screenCenter).Magnitude;
				if ((distance < CONFIG.FOVRadius) and (distance < nearestDistance)) then
					if IsVisible(head) then
						nearestDistance = distance;
						nearestPlayer = player;
					end
				end
			end
		end
	end
	return nearestPlayer;
end
local function CreateFOVCircle()
	if FOVCircle then
		pcall(function()
			FOVCircle:Remove();
		end);
	end
	FOVCircle = Drawing.new("Circle");
	FOVCircle.Radius = CONFIG.FOVRadius;
	FOVCircle.Color = Color3.fromRGB(255, 255, 255);
	FOVCircle.Thickness = 2;
	FOVCircle.Filled = false;
	FOVCircle.Transparency = 0.7;
	FOVCircle.Visible = CONFIG.AimbotEnabled;
end
local function UpdateFOVCircle()
	if not FOVCircle then
		return;
	end
	local screenSize = Camera.ViewportSize;
	local centerX = screenSize.X / 2;
	local centerY = screenSize.Y / 2;
	FOVCircle.Position = Vector2.new(centerX, centerY);
	FOVCircle.Radius = CONFIG.FOVRadius;
	FOVCircle.Visible = CONFIG.AimbotEnabled;
end
local aimbotLoop;
local function StartAimbot()
	if aimbotLoop then
		aimbotLoop:Disconnect();
	end
	CreateFOVCircle();
	aimbotLoop = RunService.RenderStepped:Connect(function()
		if (not CONFIG.AimbotEnabled or not LocalPlayer.Character) then
			return;
		end
		UpdateFOVCircle();
		local targetPlayer = GetNearestPlayerInFOV();
		if (not targetPlayer or not targetPlayer.Character) then
			return;
		end
		local head = targetPlayer.Character:FindFirstChild("Head");
		if not head then
			return;
		end
		local targetPos = head.Position + Vector3.new(0, CONFIG.HeadOffsetY, 0);
		local currentCFrame = Camera.CFrame;
		local newCFrame = CFrame.new(currentCFrame.Position, targetPos);
		Camera.CFrame = currentCFrame:Lerp(newCFrame, CONFIG.AimbotSmoothing);
	end);
end
local function StopAimbot()
	if aimbotLoop then
		aimbotLoop:Disconnect();
		aimbotLoop = nil;
	end
	if FOVCircle then
		pcall(function()
			FOVCircle:Remove();
		end);
		FOVCircle = nil;
	end
end
local lastCleanTime = 0;
local function CleanESP()
	for _, drawing in ipairs(ESPDrawings) do
		pcall(function()
			drawing:Remove();
		end);
	end
	ESPDrawings = {};
end
local function UpdateESP()
	if (not CONFIG.ESPEnabled or not LocalPlayer.Character) then
		return;
	end
	lastCleanTime = lastCleanTime + 1;
	if (lastCleanTime >= 2) then
		CleanESP();
		lastCleanTime = 0;
	else
		return;
	end
	local players = GetAllPlayers();
	for _, player in ipairs(players) do
		local head = player.Character:FindFirstChild("Head");
		if head then
			local screenPos, onScreen = Camera:WorldToViewportPoint(head.Position);
			if (onScreen and (screenPos.Z > 0)) then
				local circle = Drawing.new("Circle");
				circle.Position = Vector2.new(screenPos.X, screenPos.Y);
				circle.Radius = 8;
				circle.Color = CONFIG.ESPColor;
				circle.Thickness = 2;
				circle.Filled = false;
				circle.Transparency = 0.8;
				circle.Visible = true;
				table.insert(ESPDrawings, circle);
			end
		end
	end
end
local espLoop = RunService.RenderStepped:Connect(function()
	if CONFIG.ESPEnabled then
		UpdateESP();
	end
end);
local hitboxLoop;
local function StartHitboxExpander()
	if hitboxLoop then
		hitboxLoop:Disconnect();
	end
	hitboxLoop = RunService.RenderStepped:Connect(function()
		if not CONFIG.HitboxExpanderEnabled then
			return;
		end
		for i, v in next, Players:GetPlayers() do
			if (v.Name ~= LocalPlayer.Name) then
				pcall(function()
					if (v.Character and v.Character:FindFirstChild("Head")) then
						local head = v.Character.Head;
						if not ExpandedHeads[head] then
							ExpandedHeads[head] = {originalSize=head.Size,originalTransparency=head.Transparency,originalColor=head.BrickColor,originalMaterial=head.Material,originalCanCollide=head.CanCollide};
						end
						head.Size = Vector3.new(CONFIG.HitboxSize, CONFIG.HitboxSize, CONFIG.HitboxSize);
						head.Transparency = CONFIG.HitboxTransparency;
						head.BrickColor = BrickColor.new("Really blue");
						head.Material = "Neon";
						head.CanCollide = false;
					end
				end);
			end
		end
		for head, data in next, ExpandedHeads do
			if not head.Parent then
				ExpandedHeads[head] = nil;
			end
		end
	end);
end
local function StopHitboxExpander()
	if hitboxLoop then
		hitboxLoop:Disconnect();
		hitboxLoop = nil;
	end
	for head, data in next, ExpandedHeads do
		pcall(function()
			if head.Parent then
				head.Size = data.originalSize;
				head.Transparency = data.originalTransparency;
				head.BrickColor = data.originalColor;
				head.Material = data.originalMaterial;
				head.CanCollide = data.originalCanCollide;
			end
		end);
	end
	ExpandedHeads = {};
end
local function StartWalkSpeed()
	if WalkSpeedLoop then
		WalkSpeedLoop:Disconnect();
	end
	WalkSpeedLoop = RunService.RenderStepped:Connect(function()
		if (not CONFIG.WalkSpeedEnabled or not LocalPlayer.Character) then
			return;
		end
		pcall(function()
			local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid");
			if humanoid then
				sethiddenproperty(humanoid, "WalkSpeed", CONFIG.WalkSpeed);
			end
		end);
	end);
end
local function StopWalkSpeed()
	if WalkSpeedLoop then
		WalkSpeedLoop:Disconnect();
		WalkSpeedLoop = nil;
	end
	pcall(function()
		if LocalPlayer.Character then
			local humanoid = LocalPlayer.Character:FindFirstChildOfClass("Humanoid");
			if humanoid then
				sethiddenproperty(humanoid, "WalkSpeed", 16);
			end
		end
	end);
end
local function UpdateUIStatus()
	if AimbotStatusLabel then
		AimbotStatusLabel.Text = (CONFIG.AimbotEnabled and "ON") or "OFF";
		AimbotStatusLabel.TextColor3 = (CONFIG.AimbotEnabled and Color3.new(0, 1, 0)) or Color3.new(1, 0, 0);
	end
	if ESPStatusLabel then
		ESPStatusLabel.Text = (CONFIG.ESPEnabled and "ON") or "OFF";
		ESPStatusLabel.TextColor3 = (CONFIG.ESPEnabled and Color3.new(0, 1, 0)) or Color3.new(1, 0, 0);
	end
	if TeamCheckLabel then
		TeamCheckLabel.Text = (CONFIG.TeamCheckEnabled and "ON") or "OFF";
		TeamCheckLabel.TextColor3 = (CONFIG.TeamCheckEnabled and Color3.new(0, 1, 0)) or Color3.new(1, 0, 0);
	end
	if HitboxExpanderLabel then
		HitboxExpanderLabel.Text = (CONFIG.HitboxExpanderEnabled and "ON") or "OFF";
		HitboxExpanderLabel.TextColor3 = (CONFIG.HitboxExpanderEnabled and Color3.new(0, 1, 0)) or Color3.new(1, 0, 0);
	end
	if WalkSpeedLabel then
		WalkSpeedLabel.Text = (CONFIG.WalkSpeedEnabled and "ON") or "OFF";
		WalkSpeedLabel.TextColor3 = (CONFIG.WalkSpeedEnabled and Color3.new(0, 1, 0)) or Color3.new(1, 0, 0);
	end
	if SmoothLabel then
		SmoothLabel.Text = "Suavidade: " .. string.format("%.2f", CONFIG.AimbotSmoothing);
	end
	if FOVLabel then
		FOVLabel.Text = "FOV: " .. CONFIG.FOVRadius;
	end
	if HitboxSizeLabel then
		HitboxSizeLabel.Text = "Tamanho Cabeça: " .. CONFIG.HitboxSize;
	end
	if HitboxTransparencyLabel then
		HitboxTransparencyLabel.Text = "Transparência: " .. string.format("%.1f", CONFIG.HitboxTransparency);
	end
	if WalkSpeedSliderLabel then
		WalkSpeedSliderLabel.Text = "Velocidade: " .. CONFIG.WalkSpeed;
	end
end
local function CreateUI()
	MainUI = Instance.new("ScreenGui");
	MainUI.Name = "AimbotUniversalUI";
	MainUI.Parent = game:GetService("CoreGui");
	MainUI.ResetOnSpawn = false;
	local MainFrame = Instance.new("Frame");
	MainFrame.Name = "MainFrame";
	MainFrame.Size = UDim2.new(0, 220, 0, 430);
	MainFrame.Position = UDim2.new(0, 10, 0, 50);
	MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20);
	MainFrame.BorderSizePixel = 0;
	MainFrame.Draggable = true;
	MainFrame.Active = true;
	MainFrame.Parent = MainUI;
	local Header = Instance.new("TextLabel");
	Header.Size = UDim2.new(1, 0, 0, 30);
	Header.Position = UDim2.new(0, 0, 0, 0);
	Header.BackgroundColor3 = Color3.fromRGB(20, 20, 20);
	Header.TextColor3 = Color3.fromRGB(255, 255, 255);
	Header.Text = "AIMBOT UNIVERSAL";
	Header.Font = Enum.Font.GothamBold;
	Header.TextSize = 10;
	Header.Parent = MainFrame;
	local MinimizeBtn = Instance.new("TextButton");
	MinimizeBtn.Size = UDim2.new(0, 25, 0, 30);
	MinimizeBtn.Position = UDim2.new(1, -30, 0, 0);
	MinimizeBtn.BackgroundColor3 = Color3.fromRGB(20, 20, 20);
	MinimizeBtn.TextColor3 = Color3.fromRGB(255, 255, 255);
	MinimizeBtn.Text = "−";
	MinimizeBtn.Font = Enum.Font.GothamBold;
	MinimizeBtn.TextSize = 16;
	MinimizeBtn.Parent = MainFrame;
	local CloseBtn = Instance.new("TextButton");
	CloseBtn.Size = UDim2.new(0, 25, 0, 30);
	CloseBtn.Position = UDim2.new(1, -5, 0, 0);
	CloseBtn.BackgroundColor3 = Color3.fromRGB(255, 50, 50);
	CloseBtn.TextColor3 = Color3.fromRGB(255, 255, 255);
	CloseBtn.Text = "X";
	CloseBtn.Font = Enum.Font.GothamBold;
	CloseBtn.TextSize = 12;
	CloseBtn.Parent = MainFrame;
	UIContent = Instance.new("Frame");
	UIContent.Size = UDim2.new(1, 0, 1, -30);
	UIContent.Position = UDim2.new(0, 0, 0, 30);
	UIContent.BackgroundColor3 = Color3.fromRGB(20, 20, 20);
	UIContent.BorderSizePixel = 0;
	UIContent.Parent = MainFrame;
	local ScrollFrame = Instance.new("ScrollingFrame");
	ScrollFrame.Size = UDim2.new(1, 0, 1, 0);
	ScrollFrame.Position = UDim2.new(0, 0, 0, 0);
	ScrollFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20);
	ScrollFrame.BorderSizePixel = 0;
	ScrollFrame.ScrollBarThickness = 4;
	ScrollFrame.CanvasSize = UDim2.new(0, 0, 0, 480);
	ScrollFrame.Parent = UIContent;
	local AimbotLabel = Instance.new("TextLabel");
	AimbotLabel.Size = UDim2.new(0.5, 0, 0, 26);
	AimbotLabel.Position = UDim2.new(0, 5, 0, 5);
	AimbotLabel.BackgroundTransparency = 1;
	AimbotLabel.TextColor3 = Color3.fromRGB(255, 100, 100);
	AimbotLabel.Text = "AIMBOT (5)";
	AimbotLabel.Font = Enum.Font.Gotham;
	AimbotLabel.TextSize = 9;
	AimbotLabel.TextXAlignment = Enum.TextXAlignment.Left;
	AimbotLabel.Parent = ScrollFrame;
	AimbotButton = Instance.new("TextButton");
	AimbotButton.Size = UDim2.new(0.4, 0, 0, 22);
	AimbotButton.Position = UDim2.new(0.55, 0, 0, 7);
	AimbotButton.BackgroundColor3 = Color3.fromRGB(1, 0, 0);
	AimbotButton.TextColor3 = Color3.fromRGB(255, 255, 255);
	AimbotButton.Text = "OFF";
	AimbotButton.Font = Enum.Font.GothamBold;
	AimbotButton.TextSize = 9;
	AimbotButton.Parent = ScrollFrame;
	AimbotStatusLabel = AimbotButton;
	local ESPLabel = Instance.new("TextLabel");
	ESPLabel.Size = UDim2.new(0.5, 0, 0, 26);
	ESPLabel.Position = UDim2.new(0, 5, 0, 31);
	ESPLabel.BackgroundTransparency = 1;
	ESPLabel.TextColor3 = Color3.fromRGB(100, 255, 100);
	ESPLabel.Text = "ESP (6)";
	ESPLabel.Font = Enum.Font.Gotham;
	ESPLabel.TextSize = 9;
	ESPLabel.TextXAlignment = Enum.TextXAlignment.Left;
	ESPLabel.Parent = ScrollFrame;
	ESPButton = Instance.new("TextButton");
	ESPButton.Size = UDim2.new(0.4, 0, 0, 22);
	ESPButton.Position = UDim2.new(0.55, 0, 0, 33);
	ESPButton.BackgroundColor3 = Color3.fromRGB(1, 0, 0);
	ESPButton.TextColor3 = Color3.fromRGB(255, 255, 255);
	ESPButton.Text = "OFF";
	ESPButton.Font = Enum.Font.GothamBold;
	ESPButton.TextSize = 9;
	ESPButton.Parent = ScrollFrame;
	ESPStatusLabel = ESPButton;
	local TeamCheckLabelText = Instance.new("TextLabel");
	TeamCheckLabelText.Size = UDim2.new(0.5, 0, 0, 26);
	TeamCheckLabelText.Position = UDim2.new(0, 5, 0, 57);
	TeamCheckLabelText.BackgroundTransparency = 1;
	TeamCheckLabelText.TextColor3 = Color3.fromRGB(100, 200, 255);
	TeamCheckLabelText.Text = "TEAMCHECK (7)";
	TeamCheckLabelText.Font = Enum.Font.Gotham;
	TeamCheckLabelText.TextSize = 9;
	TeamCheckLabelText.TextXAlignment = Enum.TextXAlignment.Left;
	TeamCheckLabelText.Parent = ScrollFrame;
	TeamCheckButton = Instance.new("TextButton");
	TeamCheckButton.Size = UDim2.new(0.4, 0, 0, 22);
	TeamCheckButton.Position = UDim2.new(0.55, 0, 0, 59);
	TeamCheckButton.BackgroundColor3 = Color3.fromRGB(0, 150, 0);
	TeamCheckButton.TextColor3 = Color3.fromRGB(255, 255, 255);
	TeamCheckButton.Text = "ON";
	TeamCheckButton.Font = Enum.Font.GothamBold;
	TeamCheckButton.TextSize = 9;
	TeamCheckButton.Parent = ScrollFrame;
	TeamCheckLabel = TeamCheckButton;
	local HitboxExpanderLabelText = Instance.new("TextLabel");
	HitboxExpanderLabelText.Size = UDim2.new(0.5, 0, 0, 26);
	HitboxExpanderLabelText.Position = UDim2.new(0, 5, 0, 83);
	HitboxExpanderLabelText.BackgroundTransparency = 1;
	HitboxExpanderLabelText.TextColor3 = Color3.fromRGB(255, 150, 50);
	HitboxExpanderLabelText.Text = "HEAD HITBOX (8)";
	HitboxExpanderLabelText.Font = Enum.Font.Gotham;
	HitboxExpanderLabelText.TextSize = 9;
	HitboxExpanderLabelText.TextXAlignment = Enum.TextXAlignment.Left;
	HitboxExpanderLabelText.Parent = ScrollFrame;
	HitboxExpanderButton = Instance.new("TextButton");
	HitboxExpanderButton.Size = UDim2.new(0.4, 0, 0, 22);
	HitboxExpanderButton.Position = UDim2.new(0.55, 0, 0, 85);
	HitboxExpanderButton.BackgroundColor3 = Color3.fromRGB(1, 0, 0);
	HitboxExpanderButton.TextColor3 = Color3.fromRGB(255, 255, 255);
	HitboxExpanderButton.Text = "OFF";
	HitboxExpanderButton.Font = Enum.Font.GothamBold;
	HitboxExpanderButton.TextSize = 9;
	HitboxExpanderButton.Parent = ScrollFrame;
	HitboxExpanderLabel = HitboxExpanderButton;
	local WalkSpeedLabelText = Instance.new("TextLabel");
	WalkSpeedLabelText.Size = UDim2.new(0.5, 0, 0, 26);
	WalkSpeedLabelText.Position = UDim2.new(0, 5, 0, 109);
	WalkSpeedLabelText.BackgroundTransparency = 1;
	WalkSpeedLabelText.TextColor3 = Color3.fromRGB(200, 200, 50);
	WalkSpeedLabelText.Text = "WALKSPEED (9)";
	WalkSpeedLabelText.Font = Enum.Font.Gotham;
	WalkSpeedLabelText.TextSize = 9;
	WalkSpeedLabelText.TextXAlignment = Enum.TextXAlignment.Left;
	WalkSpeedLabelText.Parent = ScrollFrame;
	WalkSpeedButton = Instance.new("TextButton");
	WalkSpeedButton.Size = UDim2.new(0.4, 0, 0, 22);
	WalkSpeedButton.Position = UDim2.new(0.55, 0, 0, 111);
	WalkSpeedButton.BackgroundColor3 = Color3.fromRGB(1, 0, 0);
	WalkSpeedButton.TextColor3 = Color3.fromRGB(255, 255, 255);
	WalkSpeedButton.Text = "OFF";
	WalkSpeedButton.Font = Enum.Font.GothamBold;
	WalkSpeedButton.TextSize = 9;
	WalkSpeedButton.Parent = ScrollFrame;
	WalkSpeedLabel = WalkSpeedButton;
	SmoothLabel = Instance.new("TextLabel");
	SmoothLabel.Size = UDim2.new(1, -10, 0, 12);
	SmoothLabel.Position = UDim2.new(0, 5, 0, 137);
	SmoothLabel.BackgroundTransparency = 1;
	SmoothLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
	SmoothLabel.Text = "Suavidade: 0.75";
	SmoothLabel.Font = Enum.Font.Gotham;
	SmoothLabel.TextSize = 7;
	SmoothLabel.TextXAlignment = Enum.TextXAlignment.Left;
	SmoothLabel.Parent = ScrollFrame;
	SmoothSlider = Instance.new("TextBox");
	SmoothSlider.Size = UDim2.new(1, -10, 0, 16);
	SmoothSlider.Position = UDim2.new(0, 5, 0, 151);
	SmoothSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40);
	SmoothSlider.TextColor3 = Color3.fromRGB(255, 255, 255);
	SmoothSlider.Text = string.format("%.2f", CONFIG.AimbotSmoothing);
	SmoothSlider.Font = Enum.Font.Gotham;
	SmoothSlider.TextSize = 8;
	SmoothSlider.PlaceholderText = "0.1 a 1.0";
	SmoothSlider.Parent = ScrollFrame;
	FOVLabel = Instance.new("TextLabel");
	FOVLabel.Size = UDim2.new(1, -10, 0, 12);
	FOVLabel.Position = UDim2.new(0, 5, 0, 169);
	FOVLabel.BackgroundTransparency = 1;
	FOVLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
	FOVLabel.Text = "FOV: 80";
	FOVLabel.Font = Enum.Font.Gotham;
	FOVLabel.TextSize = 7;
	FOVLabel.TextXAlignment = Enum.TextXAlignment.Left;
	FOVLabel.Parent = ScrollFrame;
	FOVSlider = Instance.new("TextBox");
	FOVSlider.Size = UDim2.new(1, -10, 0, 16);
	FOVSlider.Position = UDim2.new(0, 5, 0, 183);
	FOVSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40);
	FOVSlider.TextColor3 = Color3.fromRGB(255, 255, 255);
	FOVSlider.Text = tostring(CONFIG.FOVRadius);
	FOVSlider.Font = Enum.Font.Gotham;
	FOVSlider.TextSize = 8;
	FOVSlider.PlaceholderText = "10 a 500";
	FOVSlider.Parent = ScrollFrame;
	HitboxSizeLabel = Instance.new("TextLabel");
	HitboxSizeLabel.Size = UDim2.new(1, -10, 0, 12);
	HitboxSizeLabel.Position = UDim2.new(0, 5, 0, 201);
	HitboxSizeLabel.BackgroundTransparency = 1;
	HitboxSizeLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
	HitboxSizeLabel.Text = "Tamanho Cabeça: 5";
	HitboxSizeLabel.Font = Enum.Font.Gotham;
	HitboxSizeLabel.TextSize = 7;
	HitboxSizeLabel.TextXAlignment = Enum.TextXAlignment.Left;
	HitboxSizeLabel.Parent = ScrollFrame;
	HitboxSizeSlider = Instance.new("TextBox");
	HitboxSizeSlider.Size = UDim2.new(1, -10, 0, 16);
	HitboxSizeSlider.Position = UDim2.new(0, 5, 0, 215);
	HitboxSizeSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40);
	HitboxSizeSlider.TextColor3 = Color3.fromRGB(255, 255, 255);
	HitboxSizeSlider.Text = tostring(CONFIG.HitboxSize);
	HitboxSizeSlider.Font = Enum.Font.Gotham;
	HitboxSizeSlider.TextSize = 8;
	HitboxSizeSlider.PlaceholderText = "5 a 125";
	HitboxSizeSlider.Parent = ScrollFrame;
	HitboxTransparencyLabel = Instance.new("TextLabel");
	HitboxTransparencyLabel.Size = UDim2.new(1, -10, 0, 12);
	HitboxTransparencyLabel.Position = UDim2.new(0, 5, 0, 233);
	HitboxTransparencyLabel.BackgroundTransparency = 1;
	HitboxTransparencyLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
	HitboxTransparencyLabel.Text = "Transparência: 0.9";
	HitboxTransparencyLabel.Font = Enum.Font.Gotham;
	HitboxTransparencyLabel.TextSize = 7;
	HitboxTransparencyLabel.TextXAlignment = Enum.TextXAlignment.Left;
	HitboxTransparencyLabel.Parent = ScrollFrame;
	HitboxTransparencySlider = Instance.new("TextBox");
	HitboxTransparencySlider.Size = UDim2.new(1, -10, 0, 16);
	HitboxTransparencySlider.Position = UDim2.new(0, 5, 0, 247);
	HitboxTransparencySlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40);
	HitboxTransparencySlider.TextColor3 = Color3.fromRGB(255, 255, 255);
	HitboxTransparencySlider.Text = string.format("%.1f", CONFIG.HitboxTransparency);
	HitboxTransparencySlider.Font = Enum.Font.Gotham;
	HitboxTransparencySlider.TextSize = 8;
	HitboxTransparencySlider.PlaceholderText = "0.1 a 1.0";
	HitboxTransparencySlider.Parent = ScrollFrame;
	WalkSpeedSliderLabel = Instance.new("TextLabel");
	WalkSpeedSliderLabel.Size = UDim2.new(1, -10, 0, 12);
	WalkSpeedSliderLabel.Position = UDim2.new(0, 5, 0, 265);
	WalkSpeedSliderLabel.BackgroundTransparency = 1;
	WalkSpeedSliderLabel.TextColor3 = Color3.fromRGB(255, 255, 255);
	WalkSpeedSliderLabel.Text = "Velocidade: 16";
	WalkSpeedSliderLabel.Font = Enum.Font.Gotham;
	WalkSpeedSliderLabel.TextSize = 7;
	WalkSpeedSliderLabel.TextXAlignment = Enum.TextXAlignment.Left;
	WalkSpeedSliderLabel.Parent = ScrollFrame;
	WalkSpeedSlider = Instance.new("TextBox");
	WalkSpeedSlider.Size = UDim2.new(1, -10, 0, 16);
	WalkSpeedSlider.Position = UDim2.new(0, 5, 0, 279);
	WalkSpeedSlider.BackgroundColor3 = Color3.fromRGB(40, 40, 40);
	WalkSpeedSlider.TextColor3 = Color3.fromRGB(255, 255, 255);
	WalkSpeedSlider.Text = tostring(CONFIG.WalkSpeed);
	WalkSpeedSlider.Font = Enum.Font.Gotham;
	WalkSpeedSlider.TextSize = 8;
	WalkSpeedSlider.PlaceholderText = "1 a 100";
	WalkSpeedSlider.Parent = ScrollFrame;
	MinimizeBtn.MouseButton1Click:Connect(function()
		UIMinimized = not UIMinimized;
		UIContent.Visible = not UIMinimized;
		MinimizeBtn.Text = (UIMinimized and "+") or "−";
		MainFrame.Size = (UIMinimized and UDim2.new(0, 220, 0, 30)) or UDim2.new(0, 220, 0, 430);
	end);
	CloseBtn.MouseButton1Click:Connect(function()
		MainUI:Destroy();
		StopAimbot();
		StopHitboxExpander();
		StopWalkSpeed();
		CleanESP();
	end);
	AimbotButton.MouseButton1Click:Connect(function()
		CONFIG.AimbotEnabled = not CONFIG.AimbotEnabled;
		if CONFIG.AimbotEnabled then
			StartAimbot();
		else
			StopAimbot();
		end
		UpdateUIStatus();
	end);
	ESPButton.MouseButton1Click:Connect(function()
		CONFIG.ESPEnabled = not CONFIG.ESPEnabled;
		UpdateUIStatus();
	end);
	TeamCheckButton.MouseButton1Click:Connect(function()
		CONFIG.TeamCheckEnabled = not CONFIG.TeamCheckEnabled;
		UpdateUIStatus();
	end);
	HitboxExpanderButton.MouseButton1Click:Connect(function()
		CONFIG.HitboxExpanderEnabled = not CONFIG.HitboxExpanderEnabled;
		if CONFIG.HitboxExpanderEnabled then
			StartHitboxExpander();
		else
			StopHitboxExpander();
		end
		UpdateUIStatus();
	end);
	WalkSpeedButton.MouseButton1Click:Connect(function()
		CONFIG.WalkSpeedEnabled = not CONFIG.WalkSpeedEnabled;
		if CONFIG.WalkSpeedEnabled then
			StartWalkSpeed();
		else
			StopWalkSpeed();
		end
		UpdateUIStatus();
	end);
	SmoothSlider.FocusLost:Connect(function()
		local value = tonumber(SmoothSlider.Text);
		if value then
			CONFIG.AimbotSmoothing = math.clamp(value, 0.1, 1);
			SmoothSlider.Text = string.format("%.2f", CONFIG.AimbotSmoothing);
			UpdateUIStatus();
		end
	end);
	FOVSlider.FocusLost:Connect(function()
		local value = tonumber(FOVSlider.Text);
		if value then
			CONFIG.FOVRadius = math.clamp(value, 10, 500);
			FOVSlider.Text = tostring(CONFIG.FOVRadius);
			UpdateUIStatus();
		end
	end);
	HitboxSizeSlider.FocusLost:Connect(function()
		local value = tonumber(HitboxSizeSlider.Text);
		if value then
			CONFIG.HitboxSize = math.clamp(value, 5, 125);
			HitboxSizeSlider.Text = tostring(CONFIG.HitboxSize);
			UpdateUIStatus();
		end
	end);
	HitboxTransparencySlider.FocusLost:Connect(function()
		local value = tonumber(HitboxTransparencySlider.Text);
		if value then
			CONFIG.HitboxTransparency = math.clamp(value, 0.1, 1);
			HitboxTransparencySlider.Text = string.format("%.1f", CONFIG.HitboxTransparency);
			UpdateUIStatus();
		end
	end);
	WalkSpeedSlider.FocusLost:Connect(function()
		local value = tonumber(WalkSpeedSlider.Text);
		if value then
			CONFIG.WalkSpeed = math.clamp(value, 1, 100);
			WalkSpeedSlider.Text = tostring(CONFIG.WalkSpeed);
			UpdateUIStatus();
		end
	end);
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return;
		end
		if (input.KeyCode == Enum.KeyCode.Five) then
			CONFIG.AimbotEnabled = not CONFIG.AimbotEnabled;
			if CONFIG.AimbotEnabled then
				StartAimbot();
			else
				StopAimbot();
			end
			UpdateUIStatus();
		elseif (input.KeyCode == Enum.KeyCode.Six) then
			CONFIG.ESPEnabled = not CONFIG.ESPEnabled;
			UpdateUIStatus();
		elseif (input.KeyCode == Enum.KeyCode.Seven) then
			CONFIG.TeamCheckEnabled = not CONFIG.TeamCheckEnabled;
			UpdateUIStatus();
		elseif (input.KeyCode == Enum.KeyCode.Eight) then
			CONFIG.HitboxExpanderEnabled = not CONFIG.HitboxExpanderEnabled;
			if CONFIG.HitboxExpanderEnabled then
				StartHitboxExpander();
			else
				StopHitboxExpander();
			end
			UpdateUIStatus();
		elseif (input.KeyCode == Enum.KeyCode.Nine) then
			CONFIG.WalkSpeedEnabled = not CONFIG.WalkSpeedEnabled;
			if CONFIG.WalkSpeedEnabled then
				StartWalkSpeed();
			else
				StopWalkSpeed();
			end
			UpdateUIStatus();
		end
	end);
	UpdateUIStatus();
end
CreateUI();
