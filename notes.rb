class Notes
  def initialize
    @notes = {}
  end

  def delete_note(target_uuid)
    @notes.delete(target_uuid)
  end

  def empty?
    num_notes == 0
  end

  def num_notes
    return @notes.length
  end

  def load(notes_array)
    @notes = Hash[*notes_array.map{|note| [note['note_uuid'], note]}.flatten]
  end

  def get_note(index)
    return @notes.values[index]
  end

  def set_note(note)
    @notes[note['note_uuid']] = note
  end

  def search(search_term)
    found = []
    @notes.values.each_with_index do |note, index|
      if note['body'] =~ /#{search_term}/
        found << index
      end
    end
    return found
  end
end
