-- Query Questions

-- 1. (Selection) A moviegoer wants to view a list of all movies currently playing. Find all movies that are currently playing in theatres. For this scenario, assume movies stay in theatres for 6 weeks.

SELECT  *
FROM movie
WHERE release_date BETWEEN CURRENT_DATE - INTERVAL '6 years' AND CURRENT_DATE;


-- 2. (Projection) A user wants to find basic movie information (name, genre, release date) of movies that were made in the last ten years. Find all movies that were made from 2015 onward.

SELECT title, genre, release_date
FROM movie
WHERE release_date BETWEEN '2015-01-01' AND '2025-03-18';


-- 3. (Joins) A user wants to know the Rotten Tomato ratings associated with each movie when making their decision of which movie to watch. 
-- But, they do not want to watch a movie whose RT rating is less than 75. Find all movies whose Rotten Tomato rating is equal to or greater than 75.

SELECT movie.title, movie.release_date, reception.tomato_rating
FROM movie
JOIN reception ON movie.movie_id = reception.movie_id
WHERE reception.tomato_rating >= 75;


-- 4. (Subqueries & Functions) One moviegoer wants to find the number of movies that a director has been accredited for under a specific genre. 
-- Find the number of movies that a director has done under a specific genre of movie. Also, write an example of a select statement for this function using whatever arguments you want.

CREATE OR REPLACE FUNCTION director_genre_count (director varchar(50), genre varchar(20))
RETURNS INTEGER AS $$
DECLARE dir_gen_count integer;

BEGIN
			SELECT COUNT(*) INTO dir_gen_count
			FROM MOVIE
			JOIN production ON movie.movie_id = production.movie_id
			WHERE production.director = $1-- First parameter (fixes ambiguous error)
AND movie.genre like $2; -- Second parameter (fixes ambiguous error)

RETURN dir_gen_count;
END;
$$ LANGUAGE plpgsql;


	-- Example select statement
	SELECT director_genre_count('Clint Eastwood', '%Drama%')


-- 5.(Procedure) A moviegoer is interested in an action and/or adventure film. However,  Because of this, the movies listed must have at least 1 award accredited to them. 
-- Additionally, the Rotten Tomato rating of the movie must be equal to or greater than 80. Output a list of all the movies that fit these specifications.

CREATE OR REPLACE PROCEDURE genre_city_time_rating (
	IN user_genre varchar(50), 
	IN user_city varchar(50), 
	IN start_interval time, 
	IN end_interval time, 
	IN user_tomato_rating numeric(2,0), 
	OUT movie_list TEXT
)
LANGUAGE plpgsql
AS $$
 
BEGIN
	SELECT STRING_AGG(m.title, ', ') -- Combine multiple movie titles into a single
		string
    	INTO movie_list
	FROM movie m
 
 
    	JOIN reception r ON m.movie_id = r.movie_id 
  	JOIN plays p ON m.movie_id = p.movie_id
	JOIN location l ON p.location_id = l.location_id
 
 
    	WHERE m.genre like user_genre
      	AND l.city = user_city
	AND p.time_slot BETWEEN start_interval AND end_interval
      	AND r.tomato_rating >= user_tomato_rating;
END;
$$;
 
	-- Example Execution
CALL genre_city_time_rating('%Action & Adventure%', 'San Diego', '10:30:00', '18:45:00', 50, null);


-- 6. Transaction) Movies are added to the dataset in groups of 50. Unfortunately, there was an error when inputting new movies into the “movie” table of the database. 
-- Write an SQL query that deletes any movie whose director name is “Joe Dante”, “Erik White”, or “Peter Bratt”. Remember, when deleting these movies only draw from the last 50 movies.
-- After deletion, insert new movies into the database with the following values: 

-- Title = “Atomic Makeup of a Sandwich”, Genre = “Documentary”, Duration = 121 minutes, Release Date = 5/19/24
-- Title = “HotDog: Sandwich or Not?”, Genre = “Comedy”, Duration = 96 minutes, Release Date = 9/5/18
-- Title = “Live and Let Sandwich”, Genre = “Drama”, Duration = 81 minutes, Release Date = 4/23/2003

BEGIN;

 		-- Delete incorrect movies from the last 50 entries
    DELETE FROM movie 
    WHERE movie_id IN (
        	SELECT m.movie_id 
        	FROM movie m
        	JOIN production p ON m.movie_id = p.movie_id
       		WHERE p.director IN ('Joe Dante', 'Erik White', 'Peter Bratt')
       		ORDER BY m.movie_id DESC 
        	LIMIT 50
   		 );

  	-- Insert new movies
    INSERT INTO movie (title, genre, duration, release_date) VALUES 
    			('Atomic Makeup of a Sandwich', 'Documentary', 121, '2024-05-19'),
    			('HotDog: Sandwich or Not?', 'Comedy', 96, '2018-09-05'), 
    			('Live and Let Sandwich', 'Drama', 81, '2003-04-23');

COMMIT;


-- 7.(Triggers) The database management company wants to reduce the overall number of items in their database in order to save money. 
-- Therefore, they have made a new rule that each time a movie is added to the database, the system will check all movie’s release dates. 
-- If their release date was more than 50 years ago, then that movie is automatically removed from the database. 
-- Write an SQL trigger query that automatically deletes any entry whose release date is greater than 50 years old after an insertion.

-- Trigger Function
CREATE OR REPLACE FUNCTION delete_old_movies_func()
RETURNS TRIGGER AS $$
BEGIN
			DELETE FROM movie
			WHERE release_date <= CURRENT_DATE - INTERVAL '50 years';
			RETURN NULL; -- Postgres requires trigger functions to return something

END;
$$ LANGUAGE plpgsql;

-- Trigger Execution Condition
CREATE TRIGGER delete_old_movies_trigger
AFTER INSERT OR UPDATE ON movie
FOR EACH STATEMENT
EXECUTE FUNCTION delete_old_movies_func();


-- 8. (Tables & Indexes) The company behind the database wants to better advertise movies to their users. 
-- They decided to do this by creating a new table that only includes movies whose Rotten Tomato ratings are 80 or greater. 
-- Additionally, they want a few indexes to be included in order to increase query performance. Write an SQL query that fulfills the table requirement and then write two indexes using said table.

-- Table Creation
CREATE TABLE highly_rated_movies AS
	SELECT m.movie_id, m.title, m.genre, r.tomato_rating
	FROM movie m
	JOIN reception r ON m.movie_id = r.movie_id
	WHERE r.tomato_rating >= 80;

-- Indexes
CREATE INDEX idx_title_hrm ON highly_rated_movies(title);
CREATE INDEX idx_genre_hrm ON highly_rated_movies(genre);


-- 9. (Functions) A user wants to measure which genre(s) that a specific director does well in. This is done by calculating the average Rotten Tomato score of movies that a director is accredited for. 
-- This calculation will be done for three different genres of movie, and will thus allow the user to observe which genre(s) that a director is best at. 
-- Write an SQL query that calculates the average Rotten Tomato score of a director’s movie across three different genres. 
-- The output must be ordered in ascending order. Also, write an example of a function call with a director and genres of your choice.

CREATE OR REPLACE FUNCTION director_avg_rating (director varchar(50), genre1 varchar(50), genre2 varchar(50), genre3 varchar(50))
RETURNS TABLE (genre varchar(20), avg_rt_score numeric(2,0)) AS $$ -- 2 columns, genre and avg rotten tomato score. 										

BEGIN
	RETURN QUERY -- Executes query and returns results as output

		SELECT m.genre, AVG(r.tomato_rating) AS avg_tomato_rating
		FROM movie m
		JOIN reception r ON m.movie_id = r.movie_id
		JOIN production p ON m.movie_id = p.movie_id
		WHERE p.director = $1   -- director parameter
		AND (m.genre LIKE genre1
			 OR m.genre LIKE genre2
			 OR m.genre LIKE genre3)

		GROUP BY m.genre
		ORDER BY avg_rt_score ASC;
		
END;
$$ LANGUAGE plpgsql;


-- Example Function Call
SELECT *
FROM director_avg_rating('Steven Spielberg', '%Action & Adventure%', '%Science Fiction & Fantasy%', '%Drama%');


-- 10. (Recursion) A moviegoer is a big fan of the 101 Dalmatians series. Thus, they want to view all of the movies that fall under the 101 Dalmatians franchise. 
-- Write an SQL query that outputs all the movies in the 101 Dalmatians series.

WITH RECURSIVE movies_in_series AS (
    SELECT movie_id, title, genre, duration, release_date
    FROM movie
    WHERE title LIKE '101 Dalmatians%'
	UNION
		SELECT m.movie_id, m.title, m.genre, m.duration, m.release_date
		FROM movie m
		JOIN movies_in_series mis ON  m.movie_id = mis.movie_id
	)

	SELECT * FROM movies_in_series;
