Select *
From CovidProject..CovidDeaths
Where continent is not null
-- Because where it is null the location is an entire continent and we don't want that
order by 3,4

--Select *
--From CovidProject..CovidVaccinations
--order by 3,4

-- Select Data that we are going to be using

Select Location, Date, total_cases, new_cases, total_deaths, population
From CovidProject..CovidDeaths
order by 1,2

-- Looking at Total Cases vs Total Deaths
-- Shows likelihood of dying if you contract covid in your country
Select location, date, total_cases,total_deaths, 
(CONVERT(float, total_deaths) / NULLIF(CONVERT(float, total_cases), 0)) * 100 AS Deathpercentage
From CovidProject..CovidDeaths
order by 1,2
-- Explanation on why code is written like this instead of reguarly dividing "total_deaths/total_cases"
--NULLIF(CONVERT(float, total_cases), 0): we did this because it converts the value in the total_cases column to a floating-point number, but it also checks if the value is zero. 
--If it's zero, it returns NULL instead. This is done to prevent division by zero, which is not allowed in math. 
--(CONVERT(float, total_deaths) / NULLIF(CONVERT(float, total_cases), 0)): In this line of code it does the division of total_deaths by total_cases (as floats). 
--If total_cases is zero, the division will result in NULL due to the NULLIF function.


-- Looking at Total Cases vs Population
-- Shows what percentage of population got covid in the united states
SELECT location, date, Population, total_cases, (CONVERT(float, total_cases) / Population) * 100 AS PercentPopulationInfected
From CovidProject..CovidDeaths
Where location like '%states%'
order by YEAR(date)

-- Looking at Countries with highest infection rate compared to population
SELECT location, Population, MAX(cast(total_cases as int)) as HighestInfectionCount, MAX((CONVERT(float, total_cases) / Population)) * 100 AS PercentPopulationInfected
From CovidProject..CovidDeaths
Group by location, Population
order by PercentPopulationInfected desc
-- we casted because the data wasn't coming out as accurate for highest infection count due to the data type

--LET'S BREAK THINGS UP BY CONTINENT
-- Showing Countries with highest death count per population
SELECT DISTINCT TRIM(continent) AS cleaned_continent,
    MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidProject..CovidDeaths
WHERE TRIM(continent) <> '' AND continent IS NOT NULL
GROUP BY continent
ORDER BY TotalDeathCount DESC;

 --GLOBAL NUMBERS
 -- The original code had issues handling non zero values and dividing by zero.
 --				Issue number 1. we use a CASE statement to check if each value in the New_Cases column is numeric using the ISNUMERIC function. 
 -- If it's numeric, we convert it to an integer using CAST. If it's not numeric, we treat it as '0'. 
 -- This ensures that even non-numeric values are handled without causing errors.
 --				Issue number 2. We added a CASE statement around the division calculation. If the sum of cleaned New_Cases is zero, we set the DeathPercentage to NULL. 
 --	This avoids the division by zero error.

SELECT
    date,
    SUM(CASE WHEN ISNUMERIC(New_Cases) = 1 THEN CAST(New_Cases AS INT) ELSE 0 END) AS TotalCases,
    SUM(CASE WHEN ISNUMERIC(new_deaths) = 1 THEN CAST(new_deaths AS INT) ELSE 0 END) AS TotalDeaths,
    CASE
        WHEN SUM(CASE WHEN ISNUMERIC(New_Cases) = 1 THEN CAST(New_Cases AS INT) ELSE 0 END) = 0 THEN NULL
        ELSE SUM(CASE WHEN ISNUMERIC(new_deaths) = 1 THEN CAST(new_deaths AS INT) ELSE 0 END) * 100.0 / SUM(CASE WHEN ISNUMERIC(New_Cases) = 1 THEN CAST(New_Cases AS INT) ELSE 1 END)
    END AS DeathPercentage
FROM
    CovidProject..CovidDeaths
WHERE
    continent IS NOT NULL
GROUP BY
    date
ORDER BY
    date;

 --Death percentage of entire world
 -- Encountered "Arithmetic overflow" error, by using BIGINT, I can use larger integer data type that can accommodate larger values and fix the error. 
SELECT
    SUM(CASE WHEN ISNUMERIC(New_Cases) = 1 THEN CAST(New_Cases AS BIGINT) ELSE 0 END) AS TotalCases,
    SUM(CASE WHEN ISNUMERIC(new_deaths) = 1 THEN CAST(new_deaths AS BIGINT) ELSE 0 END) AS TotalDeaths,
    CASE
        WHEN SUM(CASE WHEN ISNUMERIC(New_Cases) = 1 THEN CAST(New_Cases AS BIGINT) ELSE 0 END) = 0 THEN NULL
        ELSE SUM(CASE WHEN ISNUMERIC(new_deaths) = 1 THEN CAST(new_deaths AS BIGINT) ELSE 0 END) * 100.0 / SUM(CASE WHEN ISNUMERIC(New_Cases) = 1 THEN CAST(New_Cases AS BIGINT) ELSE 1 END)
    END AS DeathPercentage
FROM
    CovidProject..CovidDeaths
WHERE
    continent IS NOT NULL;


-- Looking at Total Population vs Vaccinations
-- Using max of rolling people vaccinated divide by vaccination to find out how many people in that country is vaccinated
--Select dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
--SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (Partition by dea.location order by dea.location, 
--dea.date) as RollingPeopleVaccinated
--, (RollingPeopleVaccinated/population)*100
--FROM CovidProject..CovidDeaths dea
--	Join CovidProject..CovidVaccinations vac
--ON dea.location = vac.location
--	AND dea.date = vac.date
--WHERE TRIM(dea.continent) <> '' AND dea.continent IS NOT NULL
--ORDER BY 2,3;

-- USING CTE for Total Population vs Vaccinations
WITH PopvsVac (Continent, Location, Date, Population, new_vaccinations, RollingPeopleVaccinated)
AS
(
    SELECT
        dea.continent,
        dea.location,
        dea.date,
        dea.population,
        vac.new_vaccinations,
        SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (PARTITION BY dea.location ORDER BY dea.location, dea.date) AS RollingPeopleVaccinated
    FROM
        CovidProject..CovidDeaths dea
    JOIN
        CovidProject..CovidVaccinations vac
    ON
        dea.location = vac.location
        AND dea.date = vac.date
    WHERE
        TRIM(dea.continent) <> '' AND dea.continent IS NOT NULL
)
SELECT *, (RollingPeopleVaccinated/Population)*100
FROM PopvsVac;
--do max too here

---- USING TEMP TABLE for Total Population vs Vaccinations. Don't like how it's being shown here.
--DROP TABLE IF EXISTS #PercentPopulationVaccinated;
--CREATE TABLE #PercentPopulationVaccinated
--(
--    Continent nvarchar(255),
--    Location nvarchar(255),
--    Date datetime,
--    Population numeric,
--    New_Vaccinations numeric,
--    RollingPeopleVaccinated numeric
--);

--INSERT INTO #PercentPopulationVaccinated
--SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
--SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (Partition by dea.location order by dea.location, 
--dea.date) as RollingPeopleVaccinated
--FROM CovidProject..CovidDeaths dea
--	Join CovidProject..CovidVaccinations vac
--ON dea.location = vac.location
--	AND dea.date = vac.date
--WHERE TRIM(dea.continent) <> '' AND dea.continent IS NOT NULL
--  AND ISNUMERIC(vac.new_vaccinations) = 1; -- Only include numeric values

--SELECT *,
--       CASE
--           WHEN Population = 0 THEN NULL
--           ELSE (RollingPeopleVaccinated / Population) * 100
--       END AS VaccinationPercentage
--FROM #PercentPopulationVaccinated;

-- creating views to store data for data vizzes
-- Solved view probelm it wasn't showing up. This is how, You have to make sure the queries are done in the CovidProject Database. So I began with the USE function
USE CovidProject
GO
CREATE VIEW PercentPopulationVaccinated AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations, 
SUM(CAST(vac.new_vaccinations AS BIGINT)) OVER (Partition by dea.location order by dea.location, 
dea.date) as RollingPeopleVaccinated
FROM CovidProject..CovidDeaths dea
	Join CovidProject..CovidVaccinations vac
ON dea.location = vac.location
	AND dea.date = vac.date
WHERE TRIM(dea.continent) <> '' AND dea.continent IS NOT NULL

-- creating view to store data for data vizzes for Countries with highest death count per population
USE CovidProject
GO
CREATE VIEW ContTotalDeathCT AS
SELECT DISTINCT TRIM(continent) AS cleaned_continent,
    MAX(CAST(total_deaths AS INT)) AS TotalDeathCount
FROM CovidProject..CovidDeaths
WHERE TRIM(continent) <> '' AND continent IS NOT NULL
GROUP BY continent;