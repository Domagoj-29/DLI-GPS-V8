-- Author: Domagoj29
-- GitHub: https://github.com/Domagoj-29
-- Workshop: https://steamcommunity.com/profiles/76561198935577915/myworkshopfiles/

-- Initializing variables and tables

local uiR=0
local uiG=0
local uiB=0

local numberChannel={}
local boolChannel={}

local PTTButton=false
local ExternalPTT=false
local muteToggle=false

local FrequencySet=0

local horizontalGap=0
local verticalGap=0

local maxDigits=6
local fourDigitTableOffset=0

local Increments={false,false,false,false,false,false}
local Decrements={false,false,false,false,false,false}
local Digits={0,0,0,0,0,0}

local incrementCapacitor={}
local decrementCapacitor={}
local digitUpDown={}

local frequencyModeCoordinatesX={0,0,0,0,0,0}

local numberDataScrollX=0
local boolDataScrollX=0

local signalStrength=0

local DataButton=false
local MuteButton=false

-- onDraw functions

local function drawFrequencyArrow(x,y,isRotated)
	if isRotated then
		screen.drawLine(x+1,y+1,x+3,y+1)
		screen.drawLine(x,y,x+4,y)
	else
		screen.drawLine(x+1,y,x+3,y)
		screen.drawLine(x,y+1,x+4,y+1)
	end
end
local function drawColon(x,y)
	screen.drawRectF(x,y+1,1,1)
	screen.drawRectF(x,y+3,1,1)
end
local function drawSignalStrengthBackground()
	screen.drawRectF(w-7,0,1,1)
	screen.drawRectF(w-5,0,1,2)
	screen.drawRectF(w-3,0,1,3)
	screen.drawRectF(w-1,0,1,4)
end
local function drawSignalStrengthIndicator(signalStrength)
	if signalStrength>0 then
		screen.drawRectF(w-7,0,1,1)
	end
	if signalStrength>0.25 then
		screen.drawRectF(w-5,0,1,2)
	end
	if signalStrength>0.5 then
		screen.drawRectF(w-3,0,1,3)
	end
	if signalStrength>0.75 then
		screen.drawRectF(w-1,0,1,4)
	end
end
local function drawInvisibleRectangles()
	screen.drawRectF(0,0,w,6)
	screen.drawRectF(0,h-2,w,2)
end
local function drawReturnArrow(shadingOffset)
	screen.drawLine(1+shadingOffset,1,3+shadingOffset,-1)
	screen.drawLine(0+shadingOffset,2,5+shadingOffset,2)
	screen.drawLine(1+shadingOffset,3,3+shadingOffset,5)
end
local function getHighlightColor(isSelected)
	if isSelected then
		return 255,127,0
	else
		return uiR,uiG,uiB
	end
end
local function getSignalColor(signalStrength)
	if signalStrength<=0.25 then
		return 255,0,0
	elseif signalStrength<=0.5 then
		return 250,70,22
	elseif signalStrength<=0.75 then
		return 255,255,0
	else
		return 8,255,8
	end
end

-- onTick functions

local function isPointInRectangle(x,y,rectX,rectY,rectW,rectH)
	return x>rectX and y>rectY and x<rectX+rectW and y<rectY+rectH
end
local function clamp(value,min,max)
	value=math.max(min,math.min(value,max))
	return value
end
local function createCapacitor()
	local oldBoolValue=false
	local chargeCounter=0
	local dischargeCounter=nil
	return function(boolValue,chargeTicks,dischargeTicks)
		if dischargeCounter==nil then
			dischargeCounter=dischargeTicks
		end

		if boolValue then
			chargeCounter=math.min(chargeCounter+1,chargeTicks)
		else
			chargeCounter=0
		end

		if oldBoolValue and not boolValue then
			dischargeCounter=0
		end

		if not boolValue and dischargeCounter<dischargeTicks then
			dischargeCounter=dischargeCounter+1
		end

		oldBoolValue=boolValue

		return (dischargeCounter>0 and dischargeCounter<dischargeTicks) or (chargeCounter==chargeTicks and boolValue)
	end
end
--[[local function createDelay()
	local counter=0
	return function(boolValue,delayTicks)
		counter=boolValue and counter+1 or delayTicks
		if counter==delayTicks or counter==1 then
			counter=0
			return true
		end
	end
end]]
local function createScrollUpDown()
	local counter=0
	return function(down,up)
		if up then
			counter=counter+1
		elseif down then
			counter=counter-1
		end
		counter=clamp(counter,-23,0)
		return counter
	end
end
local function createDigitUpDown()
	local delayTicks=15
	local timer=0
	local counter=0
	return function(up,down)
		if up or down then
			timer=timer+1
			if timer>delayTicks then
				counter=up and counter+1 or counter
				counter=down and counter-1 or counter
				timer=0
			end
		else
			timer=delayTicks
		end
		counter=(counter==-1) and 9 or counter
		counter=(counter==10) and 0 or counter
		return counter
	end
end
local function createPushToToggle()
	local oldVariable=false
	local toggleVariable=false
	return function(variable)
		if variable and not oldVariable then
			toggleVariable=not toggleVariable
		end
		oldVariable=variable
		return toggleVariable
	end
end
local function createPulse()
	local k=0
	return function(variable)
		if not variable then
			k=0
		else
			k=k+1
		end
		return k==1
	end
end
local function createStringMemoryGate()
	local storedValue="NumberData"
	return function(valueToStore,set)
		if set then
			storedValue=valueToStore
		end
		return storedValue
    end
end
local function dynamicDecimalRounding(number)
	return string.format("%.".. math.max(0,4-string.len(clamp(math.floor(number),-9999,99999))) .."f",number)
end
local function boolToString(boolValue)
	if boolValue==true then
		return "ON"
	else
		return "OFF"
	end
end

for i=1,maxDigits do
	digitUpDown[i]=createDigitUpDown()
	incrementCapacitor[i]=createCapacitor()
	decrementCapacitor[i]=createCapacitor()
end

numberDataScroll=createScrollUpDown()
boolDataScroll=createScrollUpDown()
previousDataMode=createStringMemoryGate() -- This remembers the last data (bool,number,video) mode you were in
mutePushToToggle=createPushToToggle()
returnButtonPulse=createPulse()
cycleDataModesPulse=createPulse()

local screenMode="Menu" -- "Menu","Frequency","NumberData","BoolData","VideoData"
function onTick()
	uiR=property.getNumber("UI R")
	uiG=property.getNumber("UI G")
	uiB=property.getNumber("UI B")

	local w=input.getNumber(1)
	local h=input.getNumber(2)
	local inputX=input.getNumber(3)
	local inputY=input.getNumber(4)
	signalStrength=input.getNumber(7)

	for i=1,8 do
		numberChannel[i]=dynamicDecimalRounding(input.getNumber(7+i))
	end

    local isPressed=input.getBool(1)
	ExternalPTT=input.getBool(3)

	for i=1,8 do
		boolChannel[i]=boolToString(input.getBool(3+i))
	end

	--horizontalGap=clamp((w/32-1),0,2)
	verticalGap=clamp((h/32-1),0,2)

	local ReturnButton=isPressed and isPointInRectangle(inputX,inputY,-1,-1,6,6)
	if returnButtonPulse(ReturnButton) then
		previousDataMode(screenMode,screenMode~="Frequency")
		screenMode="Menu"
	end

	maxDigits=w==32 and 4 or 6
	fourDigitTableOffset=w==32 and 1 or 0
	frequencyModeCoordinatesX={w/2+10,w/2+5,w/2,w/2-6,w/2-11,w/2-16}

	local cycleDataModes=isPressed and isPointInRectangle(inputX,inputY,w/2-9,-1,16,6)

	local Up=isPressed and isPointInRectangle(inputX,inputY,-1,-1,w+2,h/2-1)
	local Down=isPressed and isPointInRectangle(inputX,inputY,-1,h/2+1,w+2,h/2)

	DataButton=false
	local videoSwitchbox=false

	if screenMode=="Menu" then
		local FrqButton=isPressed and isPointInRectangle(inputX,inputY,w/2-8,h/2-16,15,6)
		PTTButton=isPressed and isPointInRectangle(inputX,inputY,w/2-8,h/2-10+verticalGap,15,6)
		DataButton=isPressed and isPointInRectangle(inputX,inputY,w/2-11,h/2-4+verticalGap*2,20,6)
		MuteButton=isPressed and isPointInRectangle(inputX,inputY,w/2-11,h/2+2+verticalGap*3,20,6)

		if FrqButton then
			screenMode="Frequency"
		end
		PTTButtonR,PTTButtonG,PTTButtonB=getHighlightColor(PTTButton or ExternalPTT)
		if DataButton then
			screenMode=previousDataMode(nil,false)
		end
		muteToggle=mutePushToToggle(MuteButton)
		muteButtonR,muteButtonG,muteButtonB=getHighlightColor(muteToggle)
	elseif screenMode=="Frequency" then
		for i=1,maxDigits do
			Increments[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2-9,5,6)
			Decrements[i]=isPressed and isPointInRectangle(inputX,inputY,frequencyModeCoordinatesX[i+fourDigitTableOffset],h/2+1,5,6)
			Digits[i]=digitUpDown[i](Increments[i],Decrements[i])
		end
		FrequencySet=Digits[1]+Digits[2]*10+Digits[3]*100+Digits[4]*1000+Digits[5]*10000+Digits[6]*100000
	elseif screenMode=="NumberData" then
		local notAnyButton=not (ReturnButton or DataButton or cycleDataModes)
		numberDataScrollX=h==32 and numberDataScroll(Down and notAnyButton,Up and notAnyButton) or 0

		if cycleDataModesPulse(cycleDataModes) then
			screenMode="BoolData"
		end
	elseif screenMode=="BoolData" then
		local notAnyButton=not (ReturnButton or DataButton or cycleDataModes)
		boolDataScrollX=h==32 and boolDataScroll(Down and notAnyButton,Up and notAnyButton) or 0

		if cycleDataModesPulse(cycleDataModes) then
			screenMode="VideoData"
		end
	elseif screenMode=="VideoData" then
		videoSwitchbox=true
		if cycleDataModesPulse(cycleDataModes) then
			screenMode="NumberData"
		end
	end

	output.setNumber(1,FrequencySet)

	output.setBool(1,PTTButton or ExternalPTT)
	output.setBool(2,muteToggle)
	output.setBool(3,videoSwitchbox)
	-- TODO: Full duplex version
end
function onDraw()
	w=screen.getWidth()
	h=screen.getHeight()

	if screenMode~="VideoData" then
		screen.setColor(15,15,15)
		screen.drawClear()
	end

	screen.setColor(0,0,0)
	if screenMode=="Menu" then
		screen.drawText(w/2-6,h/2-15,"FRQ")
		screen.drawText(w/2-6,h/2-9+verticalGap,"PTT")
		screen.drawText(w/2-9,h/2-3+verticalGap*2,"DATA")
		screen.drawText(w/2-9,h/2+3+verticalGap*3,"MUTE")
		screen.drawText(w-9,h-5,"V4")
		--screen.drawText(w/2-9,h/2+9,"HDPX")
	elseif screenMode=="Frequency" then
		for i=1,maxDigits do
			screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2-3,string.format("%.0f",Digits[i]))
			drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2-6,false)
			drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+2,h/2+3,true)
		end
	elseif screenMode=="NumberData" then
		for i=1,8 do
			screen.drawText(1,i*6+i*verticalGap+numberDataScrollX,string.format("%.0f",i))
			drawColon(6,i*6+i*verticalGap+numberDataScrollX)
			screen.drawTextBox(w-25,i*6+i*verticalGap+numberDataScrollX,25,5,numberChannel[i],1)
		end
		screen.drawText(w/2-7,0,"Num")
	elseif screenMode=="BoolData" then
		for i=1,8 do
			screen.drawText(1,i*6+i*verticalGap+boolDataScrollX,string.format("%.0f",i))
			drawColon(6,i*6+i*verticalGap+boolDataScrollX)
			screen.drawTextBox(w-15,i*6+i*verticalGap+boolDataScrollX,15,5,boolChannel[i],1)
		end
	elseif screenMode=="VideoData" then
		screen.drawText(w/2-7,0,"Vid")
	end

	if screenMode=="Menu" then
		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-7,h/2-15,"FRQ")
		screen.drawText(w/2-10,h/2-3+verticalGap*2,"DATA")
		screen.drawText(w-10,h-5,"V4")

		screen.setColor(getHighlightColor(PTTButton or ExternalPTT))
		screen.drawText(w/2-7,h/2-9+verticalGap,"PTT")
		screen.setColor(getHighlightColor(muteToggle))
		screen.drawText(w/2-10,h/2+3+verticalGap*3,"MUTE")
	elseif screenMode=="Frequency" then
		for i=1,maxDigits do
			screen.setColor(uiR,uiG,uiB)
			screen.drawText(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2-3,string.format("%.0f",Digits[i]))

			screen.setColor(getHighlightColor(incrementCapacitor[i](Increments[i],1,15)))
			drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2-6,false)

			screen.setColor(getHighlightColor(decrementCapacitor[i](Decrements[i],1,15)))
			drawFrequencyArrow(frequencyModeCoordinatesX[i+fourDigitTableOffset]+1,h/2+3,true)
		end
	elseif screenMode=="NumberData" then
		screen.setColor(uiR,uiG,uiB)
		for i=1,8 do
			screen.drawText(0,i*6+i*verticalGap+numberDataScrollX,string.format("%.0f",i))
			drawColon(5,i*6+i*verticalGap+numberDataScrollX)
			screen.drawTextBox(w-26,i*6+i*verticalGap+numberDataScrollX,25,5,numberChannel[i],1)
		end

		screen.setColor(15,15,15)
		drawInvisibleRectangles()

		screen.setColor(0,0,0)
		screen.drawText(w/2-7,0,"Num")

		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-8,0,"Num")
	elseif screenMode=="BoolData" then
		screen.setColor(uiR,uiG,uiB)
		for i=1,8 do
			screen.drawText(0,i*6+i*verticalGap+boolDataScrollX,string.format("%.0f",i))
			drawColon(5,i*6+i*verticalGap+boolDataScrollX)
			screen.drawTextBox(w-16,i*6+i*verticalGap+boolDataScrollX,15,5,boolChannel[i],1)
		end

		screen.setColor(15,15,15)
		drawInvisibleRectangles()

		screen.setColor(0,0,0)
		screen.drawText(w/2-7,0,"Log")

		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-8,0,"Log")
	elseif screenMode=="VideoData" then
		screen.setColor(uiR,uiG,uiB)
		screen.drawText(w/2-8,0,"Vid")
	end

	if screenMode~="Menu" then
		screen.setColor(0,0,0)
		drawReturnArrow(1)
		screen.setColor(uiR,uiG,uiB)
		drawReturnArrow(0)
	end

	if screenMode~="VideoData" then
		screen.setColor(25,25,25)
		drawSignalStrengthBackground()
	end
	screen.setColor(getSignalColor(signalStrength))
	drawSignalStrengthIndicator(signalStrength)
end
