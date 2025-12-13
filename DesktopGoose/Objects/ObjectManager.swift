import SceneKit
import Foundation

/// Manages interactive desktop objects
class ObjectManager {
    
    private weak var sceneView: GooseSceneView?
    private let screenManager: ScreenManager
    
    /// Callback when a ball is thrown (for goose to chase)
    var onBallThrown: ((DesktopObject) -> Void)?
    
    /// Callback when droid spawns (for goose to flee)
    var onDroidSpawned: ((Droid) -> Void)?
    
    /// Currently thrown ball that goose might chase
    private(set) var thrownBall: DesktopObject?
    
    /// All active objects on the desktop
    private(set) var objects: [DesktopObject] = []
    
    /// The droid enemy
    private(set) var droid: Droid?
    
    /// Timer for droid spawning
    private var droidSpawnTimer: TimeInterval = 0
    private var nextDroidSpawn: TimeInterval = 120  // First spawn after 2 minutes
    
    /// Goose collision radius for pushing objects
    let gooseRadius: CGFloat = 40
    
    /// Push force when goose collides with objects
    let pushForce: CGFloat = 300
    
    init(sceneView: GooseSceneView, screenManager: ScreenManager) {
        self.sceneView = sceneView
        self.screenManager = screenManager
        
        // Create the droid (initially hidden)
        setupDroid()
    }
    
    /// Set up the droid (initially hidden)
    private func setupDroid() {
        guard Preferences.shared.enableDroid else { return }
        
        droid = Droid()
        droid?.isHidden = true
        if let droid = droid {
            sceneView?.gooseScene.rootNode.addChildNode(droid)
        }
        
        // Randomize first spawn time (2-5 minutes)
        nextDroidSpawn = CGFloat.random(in: 120...300)
    }
    
    /// Spawn the droid to chase the goose
    func spawnDroid() {
        guard Preferences.shared.enableDroid else { return }
        guard let droid = droid, !droid.isActive else { return }
        
        let bounds = screenManager.primaryScreenBounds
        droid.spawn(screenBounds: bounds)
        
        onDroidSpawned?(droid)
    }
    
    /// Get the droid (for goose to check)
    func getDroid() -> Droid? {
        return droid
    }
    
    /// Check if ball hits droid
    private func checkDroidCollisions() {
        guard let droid = droid, droid.isActive, !droid.isKnockedOver else { return }
        
        let balls = objects.filter { $0.isThrowable }
        
        for ball in balls {
            let ballSpeed = sqrt(ball.velocity.x * ball.velocity.x + ball.velocity.y * ball.velocity.y)
            guard ballSpeed > 50 else { continue }  // Ball needs speed to knock over droid
            
            let ballPos = CGPoint(x: ball.position.x, y: ball.position.y)
            
            if droid.checkCollision(with: ballPos, radius: ball.collisionRadius) {
                // Calculate impact direction
                let dx = CGFloat(droid.position.x) - ballPos.x
                let dy = CGFloat(droid.position.y) - ballPos.y
                let distance = sqrt(dx * dx + dy * dy)
                
                if distance > 0 {
                    let impactDirection = CGPoint(x: dx / distance, y: dy / distance)
                    droid.knockOver(impactDirection: impactDirection, impactForce: ballSpeed)
                    
                    // Ball bounces back
                    ball.velocity.x = -ball.velocity.x * 0.5
                    ball.velocity.y = -ball.velocity.y * 0.5
                    
                    NSLog("⚽💥🤖 Ball hit the droid!")
                }
            }
        }
    }
    
    /// Spawn a pool ball at a random location
    func spawnPoolBall() {
        let ball = DesktopObject(modelName: "poolball", size: 50)
        ball.friction = 0.992  // Very low friction - ball keeps rolling
        ball.bounciness = 0.95  // Super bouncy - ping pong effect!
        ball.mass = 1.5
        ball.isThrowable = true
        ball.isHidingSpot = false
        ball.name = "poolball"
        
        // Random position on screen
        let bounds = screenManager.primaryScreenBounds
        let margin: CGFloat = 100
        let x = CGFloat.random(in: (bounds.minX + margin)...(bounds.maxX - margin))
        let y = CGFloat.random(in: (bounds.minY + margin)...(bounds.maxY - margin))
        
        ball.position = SCNVector3(x: x, y: y, z: 0)
        
        addObject(ball)
    }
    
    /// Spawn a football at a random location
    func spawnFootball() {
        let football = DesktopObject(modelName: "football", size: 50)
        football.friction = 0.992  // Very low friction - rolls like pool ball
        football.bounciness = 0.95  // Super bouncy - ping pong effect!
        football.mass = 1.5
        football.isThrowable = true
        football.isHidingSpot = false
        football.name = "football"
        
        // Random position on screen (different from pool ball)
        let bounds = screenManager.primaryScreenBounds
        let margin: CGFloat = 100
        let x = CGFloat.random(in: (bounds.minX + margin)...(bounds.maxX - margin))
        let y = CGFloat.random(in: (bounds.minY + margin)...(bounds.maxY - margin))
        
        football.position = SCNVector3(x: x, y: y, z: 0)
        
        addObject(football)
    }
    
    /// Spawn a plant (hiding spot, not throwable)
    func spawnPlant() {
        // Randomly choose one of the 4 plant models
        let plantModels = ["plant", "plant2", "plant3", "plant4"]
        let modelName = plantModels.randomElement() ?? "plant"
        
        let plant = DesktopObject(modelName: modelName, size: 120)
        plant.friction = 1.0  // Plants don't roll
        plant.bounciness = 0.2  // Ball bounces off a little
        plant.mass = 10  // Heavy, goose can't push it
        plant.isThrowable = false
        plant.isHidingSpot = true
        plant.collisionRadius = 25  // Tight collision around the pot/base
        
        // Position in a corner or edge of screen
        let bounds = screenManager.primaryScreenBounds
        let positions: [CGPoint] = [
            CGPoint(x: bounds.minX + 150, y: bounds.minY + 100),  // Bottom left
            CGPoint(x: bounds.maxX - 150, y: bounds.minY + 100),  // Bottom right
            CGPoint(x: bounds.minX + 150, y: bounds.maxY - 150),  // Top left
            CGPoint(x: bounds.maxX - 150, y: bounds.maxY - 150),  // Top right
        ]
        let pos = positions.randomElement() ?? CGPoint(x: bounds.minX + 150, y: bounds.minY + 100)
        
        plant.position = SCNVector3(x: pos.x, y: pos.y, z: -5)  // Slightly behind other objects
        
        addObject(plant)
    }
    
    /// Spawn multiple plants at different corners
    func spawnAllPlants() {
        let plantModels = ["plant", "plant2", "plant3", "plant4"]
        let bounds = screenManager.primaryScreenBounds
        let positions: [CGPoint] = [
            CGPoint(x: bounds.minX + 150, y: bounds.minY + 100),  // Bottom left
            CGPoint(x: bounds.maxX - 150, y: bounds.minY + 100),  // Bottom right
            CGPoint(x: bounds.minX + 150, y: bounds.maxY - 150),  // Top left
            CGPoint(x: bounds.maxX - 150, y: bounds.maxY - 150),  // Top right
        ]
        
        for (index, modelName) in plantModels.enumerated() {
            let plant = DesktopObject(modelName: modelName, size: 120)
            plant.friction = 1.0
            plant.bounciness = 0.2
            plant.mass = 10
            plant.isThrowable = false
            plant.isHidingSpot = true
            plant.collisionRadius = 25
            
            plant.position = SCNVector3(x: positions[index].x, y: positions[index].y, z: -5)
            
            addObject(plant)
        }
    }
    
    /// Spawn a couch (goose can sit on it)
    func spawnCouch() {
        let couch = DesktopObject(modelName: "couch", size: 300)  // Bigger couch!
        couch.friction = 1.0  // Couch doesn't move
        couch.bounciness = 0.3  // Ball bounces off a little
        couch.mass = 100  // Very heavy
        couch.isThrowable = false
        couch.isHidingSpot = false
        couch.name = "couch"
        couch.collisionRadius = 60  // Tighter collision bounds around visible model
        
        // Position near the bottom center of screen
        let bounds = screenManager.primaryScreenBounds
        let x = bounds.midX - 150
        let y = bounds.minY + 150
        
        couch.position = SCNVector3(x: x, y: y, z: -10)
        
        addObject(couch)
    }
    
    /// Spawn a TV (goose can watch/peck at it)
    func spawnTV() {
        let tv = DesktopObject(modelName: "tv", size: 100)
        tv.friction = 1.0  // TV doesn't move
        tv.bounciness = 0.4  // Ball bounces off nicely
        tv.mass = 50  // Heavy
        tv.isThrowable = false
        tv.isHidingSpot = false
        tv.name = "tv"
        tv.collisionRadius = 30  // Tighter collision bounds around visible model
        
        // Position near the couch
        let bounds = screenManager.primaryScreenBounds
        let x = bounds.midX + 100
        let y = bounds.minY + 100
        
        tv.position = SCNVector3(x: x, y: y, z: -5)
        
        addObject(tv)
    }
    
    /// Get the couch position (for goose to sit on)
    func getCouchPosition() -> CGPoint? {
        if let couch = objects.first(where: { $0.name == "couch" }) {
            return CGPoint(x: couch.position.x + 30, y: couch.position.y + 40)
        }
        return nil
    }
    
    /// Get the TV position (for goose to watch)
    func getTVPosition() -> CGPoint? {
        if let tv = objects.first(where: { $0.name == "tv" }) {
            // Position in front of TV
            return CGPoint(x: tv.position.x - 60, y: tv.position.y)
        }
        return nil
    }
    
    /// Get a random hiding spot position (behind plants)
    func getRandomHidingSpot() -> CGPoint? {
        let hidingSpots = objects.filter { $0.isHidingSpot }
        guard let spot = hidingSpots.randomElement() else { return nil }
        // Position behind the plant
        return CGPoint(x: spot.position.x, y: spot.position.y - 30)
    }
    
    /// Get the plant position (for goose to aim at)
    func getPlantPosition() -> CGPoint? {
        if let plant = objects.first(where: { $0.isHidingSpot && !$0.isKnockedOver }) {
            return CGPoint(x: plant.position.x, y: plant.position.y)
        }
        return nil
    }
    
    /// Spawn a pushable box
    func spawnBox() {
        let box = DesktopObject(modelName: "box", size: 100)  // Much bigger visually
        box.friction = 0.95  // Slides a bit
        box.bounciness = 0.3
        box.mass = 2.0  // Light enough to push
        box.isThrowable = true  // Can be thrown
        box.isPushable = true  // Ball/goose can push it
        box.resetsRotation = true  // Rotation resets when placed (clicked on)
        box.isHidingSpot = false
        box.name = "box"
        box.collisionRadius = 18  // Slightly larger collision
        
        // Random position on screen
        let bounds = screenManager.primaryScreenBounds
        let margin: CGFloat = 150
        let x = CGFloat.random(in: (bounds.minX + margin)...(bounds.maxX - margin))
        let y = CGFloat.random(in: (bounds.minY + margin)...(bounds.maxY - margin))
        
        box.position = SCNVector3(x: x, y: y, z: 0)
        
        addObject(box)
    }
    
    /// Get a random piece of furniture (for goose to move around)
    func getRandomFurniture() -> DesktopObject? {
        let furniture = objects.filter { !$0.isThrowable }  // Non-throwable = furniture
        return furniture.randomElement()
    }
    
    /// Check if plants are clustered together (for chaos behavior)
    func getPlantsClusteredTogether(maxDistance: CGFloat = 200) -> [DesktopObject]? {
        let plants = objects.filter { $0.isHidingSpot && !$0.isKnockedOver }
        guard plants.count >= 3 else { return nil }
        
        // Check if all plants are within maxDistance of each other
        for i in 0..<plants.count {
            for j in (i+1)..<plants.count {
                let dx = plants[i].position.x - plants[j].position.x
                let dy = plants[i].position.y - plants[j].position.y
                let distance = sqrt(dx * dx + dy * dy)
                if distance > maxDistance { return nil }
            }
        }
        return plants
    }
    
    /// Get the center position of a plant cluster
    func getPlantClusterCenter() -> CGPoint? {
        guard let plants = getPlantsClusteredTogether() else { return nil }
        
        var totalX: CGFloat = 0
        var totalY: CGFloat = 0
        for plant in plants {
            totalX += CGFloat(plant.position.x)
            totalY += CGFloat(plant.position.y)
        }
        return CGPoint(x: totalX / CGFloat(plants.count), y: totalY / CGFloat(plants.count))
    }
    
    /// Knock over all plants in a cluster
    func knockOverClusteredPlants(from direction: CGPoint) {
        guard let plants = getPlantsClusteredTogether() else { return }
        
        for plant in plants {
            if !plant.isKnockedOver {
                plant.knockOver(impactDirection: direction, impactForce: 200)
            }
        }
        NSLog("🌿💥 Goose knocked over all the plants!")
    }
    
    /// Get the position of any ball (for goose to play with)
    func getAnyBallPosition() -> CGPoint? {
        if let ball = objects.first(where: { $0.isThrowable }) {
            return CGPoint(x: ball.position.x, y: ball.position.y)
        }
        return nil
    }
    
    /// Kick a ball with given velocity
    func kickBall(velocity: CGPoint) {
        if let ball = objects.first(where: { $0.isThrowable }) {
            ball.velocity = velocity
        }
    }
    
    /// Get the velocity of any ball
    func getBallVelocity() -> CGPoint? {
        if let ball = objects.first(where: { $0.isThrowable }) {
            return ball.velocity
        }
        return nil
    }
    
    /// Add an object to the scene
    func addObject(_ object: DesktopObject) {
        sceneView?.gooseScene.rootNode.addChildNode(object)
        objects.append(object)
        sceneView?.desktopObjects = objects
    }
    
    /// Set up ball interaction callbacks
    func setupBallInteraction() {
        sceneView?.onBallPickedUp = { [weak self] ball in
            // Ball picked up - stop it from being the chase target
            if self?.thrownBall === ball {
                self?.thrownBall = nil
            }
        }
        
        sceneView?.onBallThrown = { [weak self] ball, velocity in
            // Ball thrown - goose might chase it!
            let speed = sqrt(velocity.x * velocity.x + velocity.y * velocity.y)
            if speed > 50 {  // Only chase if thrown with some force
                self?.thrownBall = ball
                self?.onBallThrown?(ball)
            }
        }
    }
    
    /// Get the position of the thrown ball (for goose to chase)
    func getThrownBallPosition() -> CGPoint? {
        guard let ball = thrownBall else { return nil }
        // Stop chasing if ball has stopped moving
        let speed = sqrt(ball.velocity.x * ball.velocity.x + ball.velocity.y * ball.velocity.y)
        if speed < 5 {
            thrownBall = nil
            return nil
        }
        return CGPoint(x: ball.position.x, y: ball.position.y)
    }
    
    /// Stop the thrown ball (goose caught it)
    func stopThrownBall() {
        thrownBall?.velocity = .zero
    }
    
    /// Throw the ball back with given velocity
    func throwBallBack(velocity: CGPoint) {
        guard let ball = thrownBall else { return }
        ball.velocity = velocity
        // The ball is still being tracked as thrownBall so goose might chase again!
    }
    
    /// Remove an object from the scene
    func removeObject(_ object: DesktopObject) {
        object.removeFromParentNode()
        objects.removeAll { $0 === object }
    }
    
    /// Track which objects are currently being touched to avoid repeated push checks
    private var objectsInContact: Set<ObjectIdentifier> = []
    
    /// Chance of goose pushing an object (0.0 - 1.0)
    let pushChance: CGFloat = 0.50  // 50% chance - goose loves pushing things!
    
    /// Update all objects (call every frame)
    func update(deltaTime: CGFloat, goosePosition: CGPoint, gooseVelocity: CGPoint) {
        let bounds = screenManager.primaryScreenBounds
        
        // Update droid spawn timer
        droidSpawnTimer += TimeInterval(deltaTime)
        if droidSpawnTimer >= nextDroidSpawn && Preferences.shared.enableDroid {
            if droid?.isActive != true {
                spawnDroid()
            }
            droidSpawnTimer = 0
            nextDroidSpawn = CGFloat.random(in: 180...420)  // Next spawn in 3-7 minutes
        }
        
        // Update droid
        if let droid = droid, droid.isActive && Preferences.shared.enableDroid {
            droid.chaseTarget(targetPosition: goosePosition, deltaTime: deltaTime)
            _ = droid.update(deltaTime: deltaTime, screenBounds: bounds)
        }
        
        // Check ball-droid collisions
        if Preferences.shared.enableDroid {
            checkDroidCollisions()
        }
        
        for object in objects {
            let objectID = ObjectIdentifier(object)
            
            // Check collision with goose
            if object.checkCollision(with: goosePosition, radius: gooseRadius) {
                // Only roll for push chance when first touching the object
                if !objectsInContact.contains(objectID) {
                    objectsInContact.insert(objectID)
                    
                    // 10% chance to push
                    if CGFloat.random(in: 0...1) < pushChance {
                        object.shouldBePushed = true
                    }
                }
                
                // Only push if we decided to push this contact
                if object.shouldBePushed {
                    let dx = CGFloat(object.position.x) - goosePosition.x
                    let dy = CGFloat(object.position.y) - goosePosition.y
                    let distance = sqrt(dx * dx + dy * dy)
                    
                    if distance > 0 {
                        let normalX = dx / distance
                        let normalY = dy / distance
                        
                        let impactForce = pushForce + sqrt(gooseVelocity.x * gooseVelocity.x + gooseVelocity.y * gooseVelocity.y)
                        
                        object.applyImpulse(CGPoint(
                            x: normalX * impactForce * deltaTime,
                            y: normalY * impactForce * deltaTime
                        ))
                        
                        // Separate objects to prevent overlap
                        let overlap = (object.collisionRadius + gooseRadius) - distance
                        if overlap > 0 {
                            object.position.x += normalX * overlap * 0.5
                            object.position.y += normalY * overlap * 0.5
                        }
                    }
                }
            } else {
                // No longer in contact - reset for next touch
                if objectsInContact.contains(objectID) {
                    objectsInContact.remove(objectID)
                    object.shouldBePushed = false
                }
            }
            
            // Update object physics
            object.update(deltaTime: deltaTime, screenBounds: bounds)
            
            // Update spin for non-throwable objects
            if !object.isThrowable {
                object.updateSpin(deltaTime: deltaTime)
            }
        }
        
        // Check ball-to-plant collisions
        checkObjectCollisions()
        
        // Check throwable-to-throwable collisions (ball hits box, etc.)
        checkThrowableCollisions()
    }
    
    /// Check for collisions between throwable objects (balls) and non-throwable objects
    private func checkObjectCollisions() {
        let balls = objects.filter { $0.isThrowable }
        let solidObjects = objects.filter { !$0.isThrowable }  // Plants, couch, TV, etc.
        
        for ball in balls {
            let ballSpeed = sqrt(ball.velocity.x * ball.velocity.x + ball.velocity.y * ball.velocity.y)
            guard ballSpeed > 10 else { continue }  // Ball needs some speed to collide
            
            for solidObject in solidObjects {
                // Check collision
                let dx = ball.position.x - solidObject.position.x
                let dy = ball.position.y - solidObject.position.y
                let distance = sqrt(dx * dx + dy * dy)
                let combinedRadius = ball.collisionRadius + solidObject.collisionRadius
                
                if distance < combinedRadius && distance > 0 {
                    let impactDirection = CGPoint(
                        x: dx / distance,
                        y: dy / distance
                    )
                    
                    // If it's a plant and moving fast, knock it over
                    if solidObject.isHidingSpot && !solidObject.isKnockedOver && ballSpeed > 100 {
                        solidObject.knockOver(impactDirection: impactDirection, impactForce: ballSpeed)
                        NSLog("💥 Ball knocked over the plant!")
                    }
                    
                    // Ball bounces off all solid objects (couch, TV, plant)
                    // Reflect velocity based on collision normal
                    let dotProduct = ball.velocity.x * impactDirection.x + ball.velocity.y * impactDirection.y
                    
                    if dotProduct < 0 {  // Only bounce if moving toward the object
                        ball.velocity.x -= 2 * dotProduct * impactDirection.x
                        ball.velocity.y -= 2 * dotProduct * impactDirection.y
                        
                        // Apply some energy loss
                        ball.velocity.x *= 0.7
                        ball.velocity.y *= 0.7
                    }
                    
                    // Separate objects to prevent overlap
                    let overlap = combinedRadius - distance
                    ball.position.x += impactDirection.x * overlap
                    ball.position.y += impactDirection.y * overlap
                }
            }
        }
    }
    
    /// Check for collisions between movable objects (ball, box) and transfer momentum
    private func checkThrowableCollisions() {
        // Include both throwable and pushable objects
        let movables = objects.filter { $0.isThrowable || $0.isPushable }
        
        // Check each pair of movable objects
        for i in 0..<movables.count {
            for j in (i+1)..<movables.count {
                let obj1 = movables[i]
                let obj2 = movables[j]
                
                // Calculate distance
                let dx = obj2.position.x - obj1.position.x
                let dy = obj2.position.y - obj1.position.y
                let distance = sqrt(dx * dx + dy * dy)
                let combinedRadius = obj1.collisionRadius + obj2.collisionRadius
                
                // Check if colliding
                if distance < combinedRadius && distance > 0 {
                    // Collision normal
                    let nx = dx / distance
                    let ny = dy / distance
                    
                    // Relative velocity
                    let dvx = obj1.velocity.x - obj2.velocity.x
                    let dvy = obj1.velocity.y - obj2.velocity.y
                    
                    // Relative velocity along collision normal
                    let dvn = dvx * nx + dvy * ny
                    
                    // Only resolve if objects are moving toward each other
                    if dvn > 0 {
                        // Calculate impulse based on masses
                        let restitution: CGFloat = 0.8  // Bounciness
                        let totalMass = obj1.mass + obj2.mass
                        let impulse = (1 + restitution) * dvn / totalMass
                        
                        // Apply impulse to each object (inversely proportional to mass)
                        obj1.velocity.x -= impulse * obj2.mass * nx
                        obj1.velocity.y -= impulse * obj2.mass * ny
                        obj2.velocity.x += impulse * obj1.mass * nx
                        obj2.velocity.y += impulse * obj1.mass * ny
                        
                        // Separate objects to prevent overlap
                        let overlap = combinedRadius - distance
                        let separationRatio1 = obj2.mass / totalMass
                        let separationRatio2 = obj1.mass / totalMass
                        
                        obj1.position.x -= nx * overlap * separationRatio1
                        obj1.position.y -= ny * overlap * separationRatio1
                        obj2.position.x += nx * overlap * separationRatio2
                        obj2.position.y += ny * overlap * separationRatio2
                    }
                }
            }
        }
    }
}

