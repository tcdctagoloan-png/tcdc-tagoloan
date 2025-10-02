<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Contact Page</title>
    
</head>

<body>
    <form  action="submit-contact" method="POST">
        @csrf
        <h1>Contact Information</h1>
        <div>
            <label for="moth_name">Mother's Name:</label>
            <input type="text" name="moth_name" id="moth_name" required>
        </div>
        <br>
        <div>
            <label for="moth_num">Mother's Contact Number:</label>
            <input type="text" name="moth_num" id="moth_num">
        </div>
        <br>
        <div>
            <label for="fath_name">Father's Name:</label>
            <input type="text" name="fath_name" id="fath_name" required>
        </div>
        <br>
        <div>
            <label for="fath_num">Father's Contact Number:</label>
            <input type="text" name="fath_num" id="fath_num">
        </div>
        <br>
        <div>
            <label for="guard_name">Guardian's Name:</label>
            <input type="text" name="guard_name" id="guard_name" required>
        </div>
        <br>
        <div>
            <label for="guard_num">Guardian's Contact Number:</label>
            <input type="text" name="guard_num" id="guard_num">
        </div>
        <br>
        <div style="text-align: center;">
            <a href="educational"><input type="button" value="Back"></a>
            <input type="submit" value="Submit">
        </div>
        <br>
    </form>
</body>

</html>
