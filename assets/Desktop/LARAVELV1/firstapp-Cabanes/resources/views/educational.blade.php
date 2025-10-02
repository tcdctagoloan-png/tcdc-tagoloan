<html>
    <body>
        <h1>Education Background</h1>
        <form action="educationalsubmit" method="POST">
           @csrf
            
           <label for="educ_id">educ_id:</label>
           <input type='text' id='educ_id' name='educ_id'><br><br>

            <label for="educ_elem">Elementary:</label>
            <input type='text' id='educ_elem' name='educ_elem'><br><br>
            
            <label for="educ_elemyear">Year Attended:</label>
            <input type='date' id='educ_elemyear' name='educ_elemyear'><br><br>
            
            <label for="educ_hschool">High School:</label>
            <input type='text' id='educ_hschool' name='educ_hschool'><br><br>
            
            <label for="educ_hschoolyear">Year Attended:</label>
            <input type='date' id='educ_hschoolyear' name='educ_hschoolyear'><br><br>
            
            <label for="educ_voc">Vocational:</label>
            <input type='text' id='educ_voc' name='educ_voc'><br><br>
            
            <label for="educ_vocyear">Year Attended:</label>
            <input type='date' id='educ_vocyear' name='educ_vocyear'><br><br>

            <button onclick="window.history.back()">Back</button>
            <input type='submit' value='Save'>
        </form>
    </body>
</html>
