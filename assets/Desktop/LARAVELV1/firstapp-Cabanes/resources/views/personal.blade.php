<html>
    <body>
        <h1>Personal Information</h1>
        <form action="personalsubmit" method="POST">
           @csrf
            <label for="per_fname">First Name:</label>
            <input type='text' id='per_fname' name='per_fname'><br><br>
            
            <label for="per_lname">Last Name:</label>
            <input type='text' id='per_lname' name='per_lname'><br><br>
            
            <label for="per_address">Your Address:</label>
            <input type='text' id='per_address' name='per_address'><br><br>
            
            <label for="per_birthday"> Your Birthday:</label>
            <input type='date' id='per_birthday' name='per_birthday'><br><br>
            
            <button type='submit'>Save</button>
        </form>
    </body>
</html>
