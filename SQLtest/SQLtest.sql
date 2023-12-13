


------------------------------------------------TASK 1--------------------------------------------------------

WITH EmployeeHierarchy AS (
    SELECT e.EmployeeId,
        e.EmployeeName,
        e.EmployeeTitle,
        CASE
            WHEN e.ManagerId IS NULL THEN e.EmployeeId
            ELSE e.ManagerId
        END AS ManagerId,
        e.EmployeeName AS ManagerName,
        e.EmployeeName AS DirectorName,
        e.EmployeeName AS PositionBreadcrumbs
    FROM EmployeeList e
    WHERE e.ManagerId IS NULL
    UNION
    SELECT e.EmployeeId,
        e.EmployeeName,
        e.EmployeeTitle,
        e.ManagerId,
        eh.EmployeeName AS ManagerName,
        eh.DirectorName AS DirectorName,
        CONCAT(eh.PositionBreadcrumbs, ' | ', e.EmployeeName) AS PositionBreadcrumbs
    FROM EmployeeList e
        INNER JOIN EmployeeHierarchy eh ON e.ManagerId = eh.EmployeeId
)
SELECT EmployeeId,
    EmployeeName,
    EmployeeTitle,
    ManagerId,
    ManagerName,
    DirectorName,
    PositionBreadcrumbs
FROM EmployeeHierarchy
ORDER BY EmployeeId;

------------------------------------------------TASK 2--------------------------------------------------------


SELECT CalendarDate,
    Employee,
    Department,
    Salary,
    MIN(Salary) OVER (PARTITION BY Employee ORDER BY Salary) AS FirstSalary,
    LAG(Salary) OVER (PARTITION BY Employee ORDER BY CalendarDate) AS PreviousSalary,
    LEAD(Salary) OVER (PARTITION BY Employee ORDER BY CalendarDate) AS NextSalary,
    SUM(Salary) OVER (PARTITION BY Department, CalendarDate) AS SumOfDepartmentSalary,
    SUM(Salary) OVER (PARTITION BY Department ORDER BY CalendarDate) AS CumulativeSumOfDepartmentsSalary
FROM Salary
order by employee


------------------------------------------------TASK 3--------------------------------------------------------

USE [DB]
GO CREATE PROCEDURE [emp].[daily_load_dimension_employee] @employee_id INT AS
SET NOCOUNT ON;
BEGIN


DECLARE @cntUpdateName INT, @cntInsertNew INT, @cntUpdateTitle INT, @cntInsertTitle INT, @cntUpdateManager INT, @cntInsertManager INT, @cntInsertSalary INT;

    -- Update EmployeeName for existing records
    UPDATE d
    SET EmployeeName = s.EmployeeName
    FROM Dimension.Employee d
    JOIN Staging.Employee s ON d.EmployeeId = s.EmployeeId;

    SET @cntUpdateName = @@ROWCOUNT;

    --Insert new Employee records
    INSERT INTO Dimension.Employee (EmployeeId, EmployeeName, EmployeeTitle, ManagerId, SalaryNumber, LoadDate)
    SELECT s.EmployeeId, s.EmployeeName, s.EmployeeTitle, s.ManagerId, s.SalaryNumber, GETDATE()
    FROM Staging.Employee s
    WHERE NOT EXISTS (
        SELECT 1
        FROM Dimension.Employee d
        WHERE d.EmployeeId = s.EmployeeId
    );

    SET @cntInsertNew = @@ROWCOUNT;

    --Update Employee Title
    UPDATE d
    SET EndDate = GETDATE()
    FROM Dimension.Employee d
    JOIN Staging.Employee s ON d.EmployeeId = s.EmployeeId
    WHERE d.EmployeeTitle != s.EmployeeTitle;

    SET @cntUpdateTitle = @@ROWCOUNT;

    INSERT INTO Dimension.Employee (EmployeeId, EmployeeName, EmployeeTitle, ManagerId, SalaryNumber, LoadDate)
    SELECT s.EmployeeId, s.EmployeeName, s.EmployeeTitle, s.ManagerId, s.SalaryNumber, GETDATE()
    FROM Staging.Employee s
    WHERE NOT EXISTS (
        SELECT 1
        FROM Dimension.Employee d
        WHERE d.EmployeeId = s.EmployeeId
    );

    SET @cntInsertTitle = @@ROWCOUNT;

    --Update Manager Id
    UPDATE d
    SET EndDate = GETDATE()
    FROM Dimension.Employee d
    JOIN Staging.Employee s ON d.EmployeeId = s.EmployeeId
    WHERE d.ManagerId != s.ManagerId;

    SET @cntUpdateManager = @@ROWCOUNT;

    INSERT INTO Dimension.Employee (EmployeeId, EmployeeName, EmployeeTitle, ManagerId, SalaryNumber, LoadDate)
    SELECT s.EmployeeId, s.EmployeeName, s.EmployeeTitle, s.ManagerId, s.SalaryNumber, GETDATE()
    FROM Staging.Employee s
    WHERE NOT EXISTS (
        SELECT 1
        FROM Dimension.Employee d
        WHERE d.EmployeeId = s.EmployeeId
    );

    SET @cntInsertManager = @@ROWCOUNT;

    --Insert Salary for the first time
    INSERT INTO Dimension.Employee (EmployeeId, SalaryNumber, LoadDate)
    SELECT s.EmployeeId, s.SalaryNumber, GETDATE()
    FROM Staging.Employee s
    WHERE NOT EXISTS (
        SELECT 1
        FROM Dimension.Employee d
        WHERE d.EmployeeId = s.EmployeeId
    );

    SET @cntInsertSalary = @@ROWCOUNT;

IF @@TRANCOUNT > 0 
	INSERT INTO LogTable (UpdateName, InsertNew, UpdateTitle, InsertTitle, UpdateManager, InsertManager, InsertSalary, LoadDate)
    VALUES (@cntUpdateName, @cntInsertNew, @cntUpdateTitle, @cntInsertTitle, @cntUpdateManager, @cntInsertManager, @cntInsertSalary, GETDATE());

	COMMIT;

SET NOCOUNT OFF;
END;