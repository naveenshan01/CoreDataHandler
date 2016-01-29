//
//  CatalogDataHandler.swift
//  
//
//  Created by Naveen Shan.
//  Copyright © 2015. All rights reserved.
//

import UIKit
import CoreData

public class CatalogDataHandler: CoreDataHandler {
    public static let sharedInstance = CatalogDataHandler()
    
    override init() {
        super.init()
        self.modelURL = NSBundle.mainBundle().URLForResource("CatalogModel", withExtension: "momd")
    }
    
    //MARK:- Products
    
    public func newProduct() -> Product {
        return self.newEntityForName("Product") as! Product
    }
    
    public func newPrice() -> Price {
        return self.newEntityForName("Price") as! Price
    }
    
    public func deleteAllProducts() -> Bool {
        return self.deleteAllObjects("Product")
    }
    
    public func getAllProducts() -> [Product]? {
        let request = NSFetchRequest.init()
        request.entity = self.entityForName("Product")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        do {
            let results = try self.managedObjectContext().executeFetchRequest(request) as! [Product]
            return results
        } catch let error as NSError {
            NSLog("Exception on getAllProducts : Error : \(error.localizedDescription)")
            return nil
        }
    }
}
