USE KANBAN
GO


UPDATE Bins
SET Capacity = MAX_Capacity,
Kanban_Card_Present = 1
GO

UPDATE Clock SET CurrentTime = '1900-01-01 00:00:00'
GO

UPDATE Globals SET Value = '1' WHERE ID = 'CurLampNum'
UPDATE Globals SET Value = '1' WHERE ID = 'CurTestTray'
GO

TRUNCATE TABLE Lamps
GO

UPDATE StockRoom SET KanBanCardPresent = 1, Inventory = 1500 WHERE PartId = 1
UPDATE StockRoom SET KanBanCardPresent = 1, Inventory = 700 WHERE PartId = 2
UPDATE StockRoom SET KanBanCardPresent = 1, Inventory = 800 WHERE PartId = 3
UPDATE StockRoom SET KanBanCardPresent = 1, Inventory = 1200 WHERE PartId = 4
UPDATE StockRoom SET KanBanCardPresent = 1, Inventory = 1800 WHERE PartId = 5
UPDATE StockRoom SET KanBanCardPresent = 1, Inventory = 1500 WHERE PartId = 6
GO

DELETE Trays
WHERE TrayNumber <> 1
GO

TRUNCATE TABLE UpcomingEvents
GO

UPDATE Workers SET IsWorking = 0
GO

EXEC StartUp
GO
