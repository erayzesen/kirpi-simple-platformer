import kirpi
import math

#region Game Properties
let cellSize:float=32
let gravity:float=30
let walkSpeed:float =200
let jumpForce:float=500
#endregion

var isGameOver=false
var isLevelFinished=false
var fadeEffectAlpha:float=0.0
var gameTimer:float=0
var gameSin:float=0.0


#region Player
type 
  Player = object
    x,y,vx,vy:float
    onFloor:bool

var player:Player
#endregion

#region Grid and Level Data: 
#[ Here, I’m using a very primitive but fun tilemap approach.
While this kind of structure is sufficient and practical for some simple games,
you might consider using tools like Tiled ]#
# S:Start Point, C:Coin, F:Finish Area, T:Trap, #:Block
var levelMap01:seq[string]= @[
  "#########################",
  "#                       #",
  "#                       #",
  "#                       #",
  "# F  CCC                #",
  "#          CC           #",
  "#########       CCC     #",
  "#         ####          #",
  "#              #####    #",
  "#                     CC#",
  "#                     ###",
  "#                  ##   #",
  "#                #      #",
  "#       S      ##        #",
  "#    #######            #",
  "#                       #",
  "#                       #",
  "#^^^^^^^^^^^^^^^^^^^^^^^#",
  "#########################",
]

type 
  CellTypes = enum
    EMPTY,
    BLOCK,
    COIN,
    TRAP,
    FINISH

var grid:seq[seq[CellTypes]]= @[]

proc posToCell(pos:float | int) : float =
  result=floor(pos/cellSize)

proc cellToPos(cell:float | int) : float =
  result=cell.float*cellSize+cellSize*0.5

proc getCell(x,y:int):CellTypes =
  if y >= 0 and y < grid.len:
    if x >= 0 and x < grid[y].len:
      return grid[y][x]
  return CellTypes.EMPTY

proc setCell(value:CellTypes,x,y:int) =
  if y >= 0 and y < grid.len:
    if x >= 0 and x < grid[y].len:
      grid[y][x]=value
  
#endregion

#region Simple GUI
proc drawGameOverPanel() =
  push()
  translate(window.getWidth().float*0.5,window.getHeight().float*0.5)
  var text=newText("Game Over!",getDefaultFont())
  var textSize=text.getSizeWith(24.0)
  var rectSize=(x:textSize.x+32,y:textSize.y+32)
  setColor("#101820")
  rectangle(DrawModes.Fill,-rectSize.x*0.5,-rectSize.y*0.5,rectSize.x,rectSize.y)
  setColor("#f0f0dc")
  draw(text,-textSize.x*0.5,-textSize.y*0.5,24)
  pop()
  
  
proc drawLevelFinishedPanel() =
  push()
  translate(window.getWidth().float*0.5,window.getHeight().float*0.5)
  var text=newText("Level Finished!",getDefaultFont())
  var textSize=text.getSizeWith(24.0)
  var rectSize=(x:textSize.x+32,y:textSize.y+32)
  setColor("#101820")
  rectangle(DrawModes.Fill,-rectSize.x*0.5,-rectSize.y*0.5,rectSize.x,rectSize.y)
  setColor("#f0f0dc")
  draw(text,-textSize.x*0.5,-textSize.y*0.5,24)
  pop()
#endregion

#region Game
proc reInitGame() =
  echo "Game Starting..."
  #Reset values
  fadeEffectAlpha=255
  isGameOver=false
  isLevelFinished=false
  gameSin=0.0
  # In a real game, this could be: var res = levelMaps[currentLevelIndex]
  var res=levelMap01
  #Parse map resource
  grid.setLen(0)
  for r in 0..<res.len:
    let row=res[r]
    var gridRow:seq[CellTypes]= @[]
    for c in 0..<row.len:
      let cell=row[c]
      if cell == '#': # Block
        gridRow.add(CellTypes.BLOCK)
      elif cell == 'C' : # Coin
        gridRow.add(CellTypes.COIN)
      elif cell == 'F' : # Finish
        gridRow.add(CellTypes.FINISH)
      elif cell == '^' : # Trap
        gridRow.add(CellTypes.TRAP)
      elif cell == 'S' : # Start Cell of the Player
        player=Player(x:c.float*cellSize+cellSize.float*0.5,y:r.float*cellSize+cellSize.float*0.5)
      else:
        gridRow.add(CellTypes.EMPTY)
    grid.add(gridRow)


proc load() =
  reInitGame()

proc update( dt:float) =
  # Fade-In Effect
  if fadeEffectAlpha>0 :
    fadeEffectAlpha-=dt*1000
  else :
    fadeEffectAlpha=0
  # For Simple Movement Animations (Coins, Finish Area)
  gameSin+=3*dt 

  
  #[ For this tutorial, I kept the walking movement and jumping simple and at a basic level. 
  This part is entirely up to your preferences, and you can experiment with different approaches.
  For example, you can make the transitions between walking and stopping smoother. 
  In platformer games, different approaches to jumping can also be applied depending on the desired feel. ]#
  #Update Player
  player.vx=0
  player.vy+=gravity*dt #apply gravity 
  #Input Logic
  if isKeyDown(KeyboardKey.Right) or isKeyDown(KeyboardKey.D) :
    player.vx=walkSpeed*dt
  if isKeyDown(KeyboardKey.Left) or isKeyDown(KeyboardKey.A) :
    player.vx= -walkSpeed*dt

  #Checking if the player is on the floor before jumping.
  if player.onFloor :
    if isKeyPressed(KeyboardKey.Up) or isKeyPressed(KeyboardKey.W) :
      player.vy= -jumpForce*dt

  #Game timer logic to wait before restarting the game
  if isLevelFinished or isGameOver :
    if gameTimer>0 : gameTimer-=dt
    else : gameTimer=0
  
  if isLevelFinished :
    if gameTimer==0 :
      reInitGame()
    return

  if isGameOver :
    player.y += player.vy 
    if gameTimer==0 :
      reInitGame()
    return

  #[ This is a very minimal but effective collision test for this type of platformer game.
  Here, we check the map cells corresponding to three points on the player’s edge (start, center, end)
  based on the player’s velocity values. Movement is tested first on the X axis by applying vx,
  then on the Y axis by applying vy. You could turn this into a generic method usable for 
  all game objects, but I didn’t do that here so it’s easier to quickly read and understand. ]#

  # Simple Tilemap Collision Solver
  let halfCellSize=cellSize*0.5
  let skin=1.0 # Offset to prevent block sticking

  #Horizontal Move & Collision
  player.x += player.vx  
  let sx:float=if player.vx<0 : -1 elif  player.vx>0 : 1 else: 0
  if sx!=0 :
    let nextCellX= posToCell(player.x+player.vx+sx*halfCellSize)
    for cs in [-1.0, 0.0, 1.0] : # Check top, middle, bottom
      let checkCellY= posToCell(player.y+( (halfCellSize-skin)*cs) )
      if getCell(nextCellX.int,checkCellY.int)==CellTypes.BLOCK :
        player.x = cellToPos(nextCellX).float-cellSize*sx
        player.vx=0

  #Vertical Move & Collision
  player.onFloor=false
  player.y += player.vy
  let sy:float=if player.vy<0 : -1 elif  player.vy>0 : 1 else: 0
  if sy!=0 :
    let nextCellY=posToCell(player.y+player.vy+sy*halfCellSize)
    for cs in [-1.0, 0.0, 1.0] : # Check left, middle, right
      let checkCellX= posToCell(player.x+(halfCellSize-skin)*cs )
      if getCell(checkCellX.int,nextCellY.int)==CellTypes.BLOCK :
        player.y = cellToPos(nextCellY)-cellSize*sy
        player.vy=0
        player.onFloor=true

  #Player Cell Positions
  let pcx=posToCell(player.x).int
  let pcy=posToCell(player.y).int
  #Current Player CellType
  let playerCell=getCell(pcx,pcy)
  
  #[ It’s a very simple collision test against game objects,
  like checking whether the player is on a coin, trap, or finish tile.
  I didn’t make it more complex, but you can also check the player
  and the surrounding cells against object cells.
  Or you can use classic AABB tests. ]#
  #Check Coin Collision
  if playerCell==CellTypes.COIN :
    setCell(CellTypes.EMPTY,pcx,pcy)
  
  #Check Trap Collision
  if playerCell==CellTypes.TRAP :
    player.vy= -jumpForce*dt
    gameTimer=3 # Activate the game timer to wait 3 seconds to restart
    isGameOver=true
  #Check Finish Collision  
  if playerCell==CellTypes.FINISH :
    gameTimer=3 # Activate the game timer to wait 3 seconds to restart
    isLevelFinished=true
  
  
proc draw() =
  clear("#736464")
  #Drawing Level Map
  for y in 0 ..< grid.len:
    for x in 0 ..< grid[y].len:
      if grid[y][x] == CellTypes.BLOCK:
        setColor("#101820")
        rectangle(DrawModes.Fill,x.float*cellSize, y.float*cellSize, cellSize, cellSize)
      elif grid[y][x] == CellTypes.COIN:
        setColor("#fac800")
        var moveDir:float=if (x mod 2)==0 : -1 else: 1
        var moveFactor=moveDir*sin(gameSin)*2
        circle(DrawModes.Fill,x.float*cellSize+cellSize*0.5,y.float*cellSize+cellSize*0.5+moveFactor,cellSize*0.25)
      elif grid[y][x] == CellTypes.FINISH:
        push()
        translate(x.float*cellSize+cellSize*0.5,y.float*cellSize+cellSize*0.5)
        rotate(gameSin)
        setColor("#00a0c8")
        rectangle(DrawModes.Fill,-cellSize*0.25, -cellSize*0.25, cellSize*0.5, cellSize*0.5)
        rotate(-gameSin*2)
        setLine(2.0)
        rectangle(DrawModes.Line,-cellSize*0.5, -cellSize*0.5, cellSize, cellSize)
        pop()
      elif grid[y][x] == CellTypes.TRAP:
        setColor("#d24040")
        #Drawing a triangle
        polygon(DrawModes.Fill,
          x.float*cellSize+cellSize*0.5, y.float*cellSize, 
          x.float*cellSize+cellSize, y.float*cellSize+cellSize,
          x.float*cellSize, y.float*cellSize+cellSize
          )
      
        
  #Draw Player
  setColor("#f0f0dc")
  rectangle(DrawModes.Fill,player.x-cellSize*0.5,player.y-cellSize*0.5,cellSize,cellSize)
  

  if isGameOver :
    drawGameOverPanel()

  if isLevelFinished :
    drawLevelFinishedPanel()

  if fadeEffectAlpha>0 :
    var col=Color("#101820")
    col.a=fadeEffectAlpha.uint8
    setColor(col)
    rectangle(DrawModes.Fill,0,0,window.getWidth().float,window.getHeight().float)



run("Untitled Game",load,update,draw)
#endregion