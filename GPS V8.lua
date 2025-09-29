function isPointInRectangle(x,y,rectX,rectY,rectW,rectH)
	return x>rectX and y>rectY and x<rectX+rectW and y<rectY+rectH
end
function getHighlightColor(isSelected)
	if isSelected then
		return 255,127,0
	else
		return uiR,uiG,uiB
	end
end
function round(value)
	value=math.floor(value+0.5)
	return value
end
function clamp(value,min,max)
	value=math.max(min,math.min(value,max))
	return value
end
function createPulse()
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
function createPushToToggle()
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
function createMemoryGate()
	local storedValue=0
	return function(valueToStore,set,reset,resetValue)
		if set then
			storedValue=valueToStore
		end
		if reset then
			storedValue=resetValue
		end
		return storedValue
	end
end
function createUpDown(startValue)
	local counter=startValue
	return function(down,up,increment,min,max,reset)
		if down then
			counter=counter-increment
		end
		if up then
			counter=counter+increment
		end
		if reset then
			counter=0
		end
		counter=math.max(min,math.min(counter,max))
		return counter
	end
end
function waypointDistance(gpsX,gpsY,waypointX,waypointY,speed)
	local differenceX=waypointX-gpsX
	local differenceY=waypointY-gpsY
	local distance=clamp(math.sqrt(differenceX*differenceX+differenceY*differenceY)/1000,0,256)
	local estimate=clamp((distance/(speed*3.6))*60,0,999)
	return distance,estimate
end
dataButtonPushToToggle=createPushToToggle()
drawLinePushToToggle=createPushToToggle()
zoomUpDown=createUpDown(1)
zoomTimeMultiplierUpDown=createUpDown(1)
upDownMovement=createUpDown(0)
leftRightMovement=createUpDown(0)
scrollUpDown=createUpDown(0)
storeX=createMemoryGate()
storeY=createMemoryGate()
mapMovementPulse=createPulse()
linePulse=createPulse()
waypointSetPulse=createPulse()


mapMovement="GPS" -- GPS/Touchscreen
zoom=1
w=0
h=0
function onTick()
	uiR=property.getNumber("UI R")
	uiG=property.getNumber("UI G")
	uiB=property.getNumber("UI B")
	pointerR=property.getNumber("Pointer R")
	pointerG=property.getNumber("Pointer G")
	pointerB=property.getNumber("Pointer B")
	lineR=property.getNumber("Line R")
	lineG=property.getNumber("Line G")
	lineB=property.getNumber("Line B")
	local propertyMultiplierX=property.getNumber("X movement multiplier")
	local propertyMultiplierY=property.getNumber("Y movement multiplier")
	local zoomMultiplier=property.getNumber("Zoom multiplier") -- Zoom of 1 equals to 1km from center to edge of screen.
	speedThreshold=property.getNumber("Minimum speed for time estimate (m/s)")

	isOverlayEnabled=property.getBool("Compass overlay")
	pointerType=property.getBool("Pointer") -- off=square on=triangle
	mapMovementSquarePointer=property.getBool("Square pointer during map movement")

	gpsX=input.getNumber(1)
	gpsY=input.getNumber(3)
	speed=input.getNumber(9)
	local compass=input.getNumber(17)
	compassDegrees=(-compass*360+360)%360

	local inputX=input.getNumber(18)
	local inputY=input.getNumber(19)
	waypointX=input.getNumber(20)
	waypointY=input.getNumber(21)

	local isPressed=input.getBool(1)

	local Up=isPressed and isPointInRectangle(inputX,inputY,-1,-1,w+1,h/2-1)
	local Down=isPressed and isPointInRectangle(inputX,inputY,-1,h/2+1,w+1,h/2-1)

	local dataMode=isPressed and isPointInRectangle(inputX,inputY,w-26,h-8,7,9)
	dataScreenToggle=dataButtonPushToToggle(dataMode)

	if not dataScreenToggle then
		local Left=isPressed and isPointInRectangle(inputX,inputY,-1,-1,w/2-1,h+1)
		local Right=isPressed and isPointInRectangle(inputX,inputY,w/2+1,-1,w+1,h+1)
		if Left or Right or Up or Down then
			mapMovement="Touchscreen"
		end

		zoomDecrease=isPressed and isPointInRectangle(inputX,inputY,w-7,h-8,8,9)
		zoomIncrease=isPressed and isPointInRectangle(inputX,inputY,w-14,h-8,8,9)
		zoomTimeMultiplier=zoomTimeMultiplierUpDown(false,zoomDecrease or zoomIncrease,0.1,1,3,not (zoomDecrease or zoomIncrease))
		zoom=zoomUpDown(zoomIncrease,zoomDecrease,0.03*zoomTimeMultiplier*zoomMultiplier,0.1,50,false)

		resetMovement=isPressed and isPointInRectangle(inputX,inputY,w-20,h-8,7,9)
		if resetMovement then
			mapMovement="GPS"
		end

		local drawLine=isPressed and isPointInRectangle(inputX,inputY,w-32,h-8,7,9)
		local drawLinePulse=false
		if waypointX==0 and waypointY==0 then
			drawLine=false
			if drawLineToggle then
				drawLinePulse=true
			end
		end
		drawLineToggle=drawLinePushToToggle(drawLine or linePulse(drawLinePulse))


		local notAnyButton=not (dataMode or resetMovement or drawLine or zoomIncrease or zoomDecrease)
		local movementMultiplierX=math.abs((w/2-inputX)*zoom*propertyMultiplierX)
		local movementMultiplierY=math.abs((h/2-inputY)*zoom*propertyMultiplierY)

		local movementX=leftRightMovement(Left and notAnyButton,Right and notAnyButton,0.5*movementMultiplierX,-128000-gpsX,128000-gpsX,resetMovement)
		local movementY=upDownMovement(Down and notAnyButton,Up and notAnyButton,0.5*movementMultiplierY,-128000-gpsY,128000-gpsY,resetMovement)

		storedX=storeX(gpsX,mapMovement=="GPS",resetMovement,gpsX)+movementX
		storedY=storeY(gpsY,mapMovement=="GPS",resetMovement,gpsY)+movementY

		pointerX,pointerY=map.mapToScreen(storedX,storedY,zoom,w,h,gpsX,gpsY)
		screenWaypointX,screenWaypointY=map.mapToScreen(storedX,storedY,zoom,w,h,waypointX,waypointY)
	else
		distance,estimate=waypointDistance(gpsX,gpsY,waypointX,waypointY,speed)
		if h<35 and not (waypointX==0 and waypointY==0) then
			scrollY=scrollUpDown(Down and not dataMode,Up and not dataMode,1,-21,0,waypointSetPulse(waypointX~=0 and waypointY~=0))
		else
			scrollY=0
		end
	end
end
function onDraw()
	w=screen.getWidth()
	h=screen.getHeight()

	screen.setColor(15,15,15)
	screen.drawClear()

	local waypointSet=not (waypointX==0 and waypointY==0)

	if not dataScreenToggle then
		screen.setMapColorOcean(0,0,0,2)
		screen.setMapColorShallows(0,0,0,40)
		screen.setMapColorLand(0,0,0,100)
		screen.setMapColorGrass(0,0,0,100)
		screen.setMapColorSand(0,0,0,100)
		screen.setMapColorSnow(0,0,0,200)
		screen.setMapColorRock(0,0,0,60)
		screen.setMapColorGravel(0,0,0,120)
		screen.drawMap(storedX,storedY,zoom)

		if drawLineToggle then
			screen.setColor(lineR,lineG,lineB)
			screen.drawLine(pointerX,pointerY,screenWaypointX,screenWaypointY)
		end
		if waypointSet then
			screen.setColor(255,127,0)
			screen.drawRectF(screenWaypointX,screenWaypointY,2,2)
		end

		screen.setColor(0,0,0)
		drawCompassOverlay(compassDegrees,1,isOverlayEnabled)
		if waypointSet then screen.drawText(w-29,h-6,"L") end
		screen.drawText(w-17,h-6,"R")
		screen.drawLine(w-11,h-4,w-6,h-4)
		screen.drawLine(w-9,h-6,w-9,h-1)
		screen.drawLine(w-4,h-4,w,h-4)

		screen.setColor(uiR,uiG,uiB)
		drawCompassOverlay(compassDegrees,0,isOverlayEnabled)


		if waypointSet then
			screen.setColor(getHighlightColor(drawLineToggle))
			screen.drawText(w-30,h-6,"L")
		end

		screen.setColor(getHighlightColor(resetMovement))
		screen.drawText(w-18,h-6,"R")

		screen.setColor(getHighlightColor(zoomIncrease))
		screen.drawLine(w-12,h-4,w-7,h-4)
		screen.drawLine(w-10,h-6,w-10,h-1)

		screen.setColor(getHighlightColor(zoomDecrease))
		screen.drawLine(w-5,h-4,w-1,h-4)

		screen.setColor(uiR,uiG,uiB)
		if pointerType then
			drawTrianglePointer(pointerX,pointerY,compassDegrees)
		else
			screen.drawRectF(pointerX,pointerY,2,2)
		end
		if mapMovement=="Touchscreen" and mapMovementSquarePointer==true then
			screen.drawRectF(w/2-1,h/2-1,2,2)
		end
	else
		local digitCount=string.len(string.format("%.0f",compassDegrees))
		screen.setColor(0,0,0)
		screen.drawTextBox(w/2-17,2+scrollY,35,5,string.format("%.0f",gpsX),0)
		screen.drawTextBox(w/2-17,9+scrollY,35,5,string.format("%.0f",gpsY),0)
		screen.drawTextBox(h/2-7,16+scrollY,15,5,string.format("%.0f",compassDegrees),0)
		screen.drawCircle((h/2-7)+round((15-digitCount*5)/2)+(digitCount*5+1),16+scrollY,1)-- Formula for textBox center alignment, alignedX=textBoxX+(textBoxWidth-textWidth)/2
		if waypointSet then
			screen.drawTextBox(h/2-14,23+scrollY,30,5,string.format("%.".. 3-string.len(math.floor(distance)) .."f",distance).."km",0) -- Depending on digit count the number will have more or less decimal places
			if speed>speedThreshold then
				screen.drawTextBox(h/2-9,30+scrollY,20,5,string.format("%.0f",estimate).."m",0)
			end
		end

		screen.setColor(uiR,uiG,uiB)
		screen.drawTextBox(w/2-18,2+scrollY,35,5,string.format("%.0f",gpsX),0)
		screen.drawTextBox(w/2-18,9+scrollY,35,5,string.format("%.0f",gpsY),0)
		screen.drawTextBox(h/2-8,16+scrollY,15,5,string.format("%.0f",compassDegrees),0)
		screen.drawCircle((h/2-8)+round((15-digitCount*5)/2)+(digitCount*5+1),16+scrollY,1)
		if waypointSet then
			screen.drawTextBox(h/2-15,23+scrollY,30,5,string.format("%.".. 3-string.len(math.floor(distance)) .."f",distance).."km",0)
			if speed>speedThreshold then
				screen.drawTextBox(h/2-10,30+scrollY,20,5,string.format("%.0f",estimate).."m",0)
			end
		end

		screen.setColor(15,15,15)
		screen.drawRectF(0,0,32,2)
		screen.drawRectF(0,h-9,32,9)
	end
	screen.setColor(0,0,0)
	screen.drawText(w-23,h-6,"D")
	screen.setColor(getHighlightColor(dataScreenToggle))
	screen.drawText(w-24,h-6,"D")
end
function rotatePoint(x,y,angle)
	return x*math.cos(angle)-y*math.sin(angle),x*math.sin(angle)+y*math.cos(angle)
end
function drawTrianglePointer(x,y,heading)
	local angle=math.rad(heading)
	local tipX,tipY=rotatePoint(0,-5,angle)
	local bottomLeftX,bottomLeftY=rotatePoint(-3,3,angle)
	local bottomRightX,bottomRightY=rotatePoint(3,3,angle)
	screen.drawTriangleF(x+tipX,y+tipY,x+bottomLeftX,y+bottomLeftY,x+bottomRightX,y+bottomRightY)
end
function drawCompassOverlay(compassDegrees,shadingOffset,enabled)
	if enabled then
		if compassDegrees>340 or compassDegrees<20 then
			screen.drawText(w/2-2+shadingOffset,2,"N")
		elseif compassDegrees<70 then
			screen.drawText(w/2-5+shadingOffset,2,"N")
			screen.drawText(w/2+1+shadingOffset,2,"E")
		elseif compassDegrees<110 then
			screen.drawText(w/2-2+shadingOffset,2,"E")
		elseif compassDegrees<160 then
			screen.drawText(w/2-5+shadingOffset,2,"S")
			screen.drawText(w/2+1+shadingOffset,2,"E")
		elseif compassDegrees<200 then
			screen.drawText(w/2-2+shadingOffset,2,"S")
		elseif compassDegrees<250 then
			screen.drawText(w/2-5+shadingOffset,2,"S")
			screen.drawText(w/2+1+shadingOffset,2,"W")
		elseif compassDegrees<290 then
			screen.drawText(w/2-2+shadingOffset,2,"W")
		else
			screen.drawText(w/2-5+shadingOffset,2,"N")
			screen.drawText(w/2+1+shadingOffset,2,"W")
		end
	end

end


