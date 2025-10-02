<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Educational Page</title>
    
</head>
<body>
    <form action="submit-educational" method="POST">
        @csrf
        <h1>Educational Information</h1>
        <div>
            <label for="educ_elem">Elementary Education:</label>
            <input type="text" name="educ_elem" id="educ_elem" placeholder="Enter elementary school name">
        </div>
        <br>
        <div>
            <label for="educ_elem_year">Date Graduated:</label>
            <input type="date" name="educ_elem_year" id="educ_elem_year">
        </div>
        <br>
        <div>
            <label for="educ_hschool">High School Education:</label>
            <input type="text" name="educ_hschool" id="educ_hschool" placeholder="Enter high school name">
        </div>
        <br>
        <div>
            <label for="educ_hschool_year">Date Graduated:</label>
            <input type="date" name="educ_hschool_year" id="educ_hschool_year">
        </div>
        <br>
        <div>
            <label for="educ_voc">Vocational Education:</label>
            <input type="text" name="educ_voc" id="educ_voc" placeholder="Enter vocational school name">
        </div>
        <br>
        <div>
            <label for="educ_voc_year">Date Graduated:</label>
            <input type="date" name="educ_voc_year" id="educ_voc_year">
        </div>
        <br>
        <div>
            <a href="personal"><input type="button" value="Back"></a>
            <input type="submit" value="Save">
        </div>
        <br>
    </form>
</body>
</html>
