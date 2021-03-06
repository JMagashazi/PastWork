USE [master]
GO
/****** Object:  Database [KANBAN]    Script Date: 2014-10-06 1:29:36 PM ******/
CREATE DATABASE [KANBAN]
 CONTAINMENT = NONE
 ON  PRIMARY 
( NAME = N'KANBAN', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\KANBAN.mdf' , SIZE = 4160KB , MAXSIZE = UNLIMITED, FILEGROWTH = 1024KB )
 LOG ON 
( NAME = N'KANBAN_log', FILENAME = N'C:\Program Files\Microsoft SQL Server\MSSQL11.MSSQLSERVER\MSSQL\DATA\KANBAN_log.ldf' , SIZE = 1040KB , MAXSIZE = 2048GB , FILEGROWTH = 10%)
GO
ALTER DATABASE [KANBAN] SET COMPATIBILITY_LEVEL = 110
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
begin
EXEC [KANBAN].[dbo].[sp_fulltext_database] @action = 'enable'
end
GO
ALTER DATABASE [KANBAN] SET ANSI_NULL_DEFAULT OFF 
GO
ALTER DATABASE [KANBAN] SET ANSI_NULLS OFF 
GO
ALTER DATABASE [KANBAN] SET ANSI_PADDING OFF 
GO
ALTER DATABASE [KANBAN] SET ANSI_WARNINGS OFF 
GO
ALTER DATABASE [KANBAN] SET ARITHABORT OFF 
GO
ALTER DATABASE [KANBAN] SET AUTO_CLOSE OFF 
GO
ALTER DATABASE [KANBAN] SET AUTO_CREATE_STATISTICS ON 
GO
ALTER DATABASE [KANBAN] SET AUTO_SHRINK OFF 
GO
ALTER DATABASE [KANBAN] SET AUTO_UPDATE_STATISTICS ON 
GO
ALTER DATABASE [KANBAN] SET CURSOR_CLOSE_ON_COMMIT OFF 
GO
ALTER DATABASE [KANBAN] SET CURSOR_DEFAULT  GLOBAL 
GO
ALTER DATABASE [KANBAN] SET CONCAT_NULL_YIELDS_NULL OFF 
GO
ALTER DATABASE [KANBAN] SET NUMERIC_ROUNDABORT OFF 
GO
ALTER DATABASE [KANBAN] SET QUOTED_IDENTIFIER OFF 
GO
ALTER DATABASE [KANBAN] SET RECURSIVE_TRIGGERS OFF 
GO
ALTER DATABASE [KANBAN] SET  ENABLE_BROKER 
GO
ALTER DATABASE [KANBAN] SET AUTO_UPDATE_STATISTICS_ASYNC OFF 
GO
ALTER DATABASE [KANBAN] SET DATE_CORRELATION_OPTIMIZATION OFF 
GO
ALTER DATABASE [KANBAN] SET TRUSTWORTHY OFF 
GO
ALTER DATABASE [KANBAN] SET ALLOW_SNAPSHOT_ISOLATION OFF 
GO
ALTER DATABASE [KANBAN] SET PARAMETERIZATION SIMPLE 
GO
ALTER DATABASE [KANBAN] SET READ_COMMITTED_SNAPSHOT OFF 
GO
ALTER DATABASE [KANBAN] SET HONOR_BROKER_PRIORITY OFF 
GO
ALTER DATABASE [KANBAN] SET RECOVERY FULL 
GO
ALTER DATABASE [KANBAN] SET  MULTI_USER 
GO
ALTER DATABASE [KANBAN] SET PAGE_VERIFY CHECKSUM  
GO
ALTER DATABASE [KANBAN] SET DB_CHAINING OFF 
GO
ALTER DATABASE [KANBAN] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF ) 
GO
ALTER DATABASE [KANBAN] SET TARGET_RECOVERY_TIME = 0 SECONDS 
GO
USE [KANBAN]
GO
/****** Object:  StoredProcedure [dbo].[FillBins]    Script Date: 2014-10-06 1:29:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE Procedure [dbo].[FillBins]
AS
--Every 5 mins (300 seconds)
DECLARE @UpdateTime datetime
SELECT @UpdateTime = DATEADD(mm, 5, CurrentTime) FROM Clock

UPDATE b
SET b.Capacity = b.Capacity + CASE WHEN b.Max_Capacity < sr.Inventory THEN b.Max_Capacity ELSE sr.Inventory END
FROM Bins b
INNER JOIN StockRoom sr
	ON sr.PartID = b.PartID
WHERE b.Kanban_Card_Present = 0

UPDATE sr
SET sr.Inventory = sr.Inventory - CASE WHEN b.Max_Capacity < sr.Inventory THEN b.Max_Capacity ELSE sr.Inventory END
FROM StockRoom sr
INNER JOIN Bins b
ON b.PartID = sr.PartId
WHERE b.Kanban_Card_Present = 0

UPDATE Bins
SET Kanban_Card_Present = 1
WHERE Kanban_Card_Present = 0

UPDATE Bins
SET Kanban_Card_Present = 0
WHERE Capacity <= Refill_Level



INSERT INTO UpcomingEvents (ProcedureName, TriggerTime)
VALUES ('FillBins', @UpdateTime)

;

GO
/****** Object:  StoredProcedure [dbo].[RefillStock]    Script Date: 2014-10-06 1:29:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RefillStock] (@PartId int)
AS

UPDATE StockRoom
SET Inventory = Inventory + ReorderAmount,
KanBanCardPresent = 1
WHERE PartId = @PartId

;
GO
/****** Object:  StoredProcedure [dbo].[RunSimulation]    Script Date: 2014-10-06 1:29:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[RunSimulation] (@EndTime datetime)
AS

UPDATE Clock 
SET StopTime = @EndTime

While (SELECT CurrentTime FROM Clock) <= @EndTime 
BEGIN
EXEC Tick

UPDATE Clock
SET CurrentTime = DATEADD(ss, 1, CurrentTime)
END
;
GO
/****** Object:  StoredProcedure [dbo].[StartUp]    Script Date: 2014-10-06 1:29:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[StartUp]
AS

-- start up workers 
EXEC WorkerComplete 1
EXEC WorkerComplete 2
EXEC WorkerComplete 3

-- start up runner
EXEC FillBins

;

GO
/****** Object:  StoredProcedure [dbo].[Tick]    Script Date: 2014-10-06 1:29:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[Tick]
AS

--Grab all events that need to fire
--Fire each one

DECLARE @ProcName varchar(100)
DECLARE @Arg1 int
DECLARE @sqlstring varchar(max)


DECLARE eventsToRun CURSOR FOR
SELECT ProcedureName, Arg1
FROM UpcomingEvents
WHERE Done = 0
AND TriggerTime <= (SELECT CurrentTime FROM Clock)

OPEN eventsToRun

FETCH NEXT FROM eventsToRun INTO @ProcName, @Arg1

WHILE @@FETCH_STATUS = 0
BEGIN
SET @sqlstring = @procName + ' ' + ISNULL(@Arg1, '')
EXEC (@sqlstring)

FETCH NEXT FROM eventsToRun INTO @ProcName, @Arg1
END

UPDATE UpcomingEvents
SET Done = 1
WHERE Done = 0
AND TriggerTime <= (SELECT CurrentTime FROM Clock)

;
GO
/****** Object:  StoredProcedure [dbo].[WorkerComplete]    Script Date: 2014-10-06 1:29:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE PROCEDURE [dbo].[WorkerComplete] (@WorkerNum int)
AS

--If worker is working
	--Lamp is completed and created
IF ((SELECT IsWorking FROM Workers WHERE ID = @WorkerNum) = 1)
BEGIN

DECLARE @TrayID int
DECLARE @LampNum int
SELECT @TrayID= t.ID FROM Trays t
	WHERE t.TrayNumber = (SELECT Value FROM Globals WHERE ID = 'CurTestTray')
SELECT @LampNum = Value FROM Globals WHERE ID = 'CurLampNum'

DECLARE @UpdateTime datetime
SELECT @UpdateTime = DATEADD(ss, (SELECT CompletionTimeSeconds FROM Workers WHERE ID = @WorkerNum), CurrentTime) FROM Clock

INSERT INTO Lamps (TrayID, LampNumber)
VALUES (@TrayID, @LampNum)
END

IF ((SELECT MIN(Capacity) FROM Bins) > 0)
BEGIN
UPDATE Bins
SET Capacity = Capacity - 1

UPDATE Workers
SET IsWorking = 1
WHERE ID = @WorkerNum

INSERT INTO UpcomingEvents (ProcedureName, TriggerTime, Arg1)
VALUES ('WorkerComplete', @UpdateTime, @WorkerNum)
END

ELSE
BEGIN
UPDATE Workers
SET IsWorking = 0
WHERE ID = @WorkerNum
END

--If parts available
	--Reduce part counts
	--Set to working
	--Insert into upcoming events table
--If NOT available
	--Set to NOT WORKING

;




GO
/****** Object:  Table [dbo].[Bins]    Script Date: 2014-10-06 1:29:36 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Bins](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[PartID] [int] NOT NULL,
	[Capacity] [int] NOT NULL,
	[Max_Capacity] [int] NOT NULL,
	[Refill_Level] [int] NOT NULL,
	[Kanban_Card_Present] [bit] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Clock]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Clock](
	[CurrentTime] [datetime] NULL,
	[StopTime] [datetime] NULL
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Globals]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Globals](
	[ID] [varchar](100) NOT NULL,
	[Value] [varchar](200) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Lamps]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Lamps](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[TrayID] [int] NOT NULL,
	[LampNumber] [int] NULL,
	[Pass] [bit] NULL,
	[TestUnitNumber] [char](10) NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Parts]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[Parts](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[Name] [varchar](50) NULL,
 CONSTRAINT [pk_PartID] PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[StockRoom]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[StockRoom](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[PartId] [int] NOT NULL,
	[Inventory] [int] NULL,
	[ReorderLimit] [int] NULL,
	[ReorderAmount] [int] NULL,
	[ReorderTimeHours] [int] NULL,
	[KanBanCardPresent] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[Trays]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Trays](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[TrayNumber] [int] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
/****** Object:  Table [dbo].[UpcomingEvents]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[UpcomingEvents](
	[ID] [int] IDENTITY(1,1) NOT NULL,
	[ProcedureName] [varchar](100) NULL,
	[TriggerTime] [datetime] NULL,
	[Arg1] [int] NULL,
	[Arg2] [int] NULL,
	[Arg3] [varchar](200) NULL,
	[Notes] [varchar](200) NULL,
	[Done] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
SET ANSI_PADDING OFF
GO
/****** Object:  Table [dbo].[Workers]    Script Date: 2014-10-06 1:29:37 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Workers](
	[ID] [int] NOT NULL,
	[CompletionTimeSeconds] [int] NULL,
	[IsWorking] [bit] NULL,
PRIMARY KEY CLUSTERED 
(
	[ID] ASC
)WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON) ON [PRIMARY]
) ON [PRIMARY]

GO
ALTER TABLE [dbo].[UpcomingEvents] ADD  DEFAULT ((0)) FOR [Done]
GO
ALTER TABLE [dbo].[Bins]  WITH CHECK ADD FOREIGN KEY([PartID])
REFERENCES [dbo].[Parts] ([ID])
GO
ALTER TABLE [dbo].[Lamps]  WITH CHECK ADD FOREIGN KEY([TrayID])
REFERENCES [dbo].[Trays] ([ID])
GO
ALTER TABLE [dbo].[StockRoom]  WITH CHECK ADD FOREIGN KEY([PartId])
REFERENCES [dbo].[Parts] ([ID])
GO
USE [master]
GO
ALTER DATABASE [KANBAN] SET  READ_WRITE 
GO
